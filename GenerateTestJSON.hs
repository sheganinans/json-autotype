{-# LANGUAGE TemplateHaskell      #-}
{-# LANGUAGE ScopedTypeVariables  #-}
{-# LANGUAGE OverloadedStrings    #-}
{-# LANGUAGE DeriveGeneric        #-}
{-# LANGUAGE StandaloneDeriving   #-}
{-# LANGUAGE ViewPatterns         #-}
{-# LANGUAGE FlexibleInstances    #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}
module Main where

import           Control.Applicative
import           Data.Maybe
import           System.Exit
import           System.IO                 (stdin, stderr, stdout, IOMode(..))
import           System.FilePath           (splitExtension, (<.>))
import           System.Process            (system)
import           Control.Monad             (forM_, forM, when)
import qualified Data.ByteString.Lazy.Char8 as BSL
import qualified Data.HashMap.Strict        as Map
import           Data.Aeson
import           Data.Function             (on)
import           Data.List
import qualified Data.Text                  as Text
import qualified Data.Text.IO               as Text
import           Data.Text                 (Text)
import qualified Data.Vector                as V
import           Data.Scientific           (scientific, Scientific)
import           Text.PrettyPrint.GenericPretty (pretty)
import           Test.QuickCheck

import           Data.Aeson.AutoType.Pretty
import           Data.Aeson.AutoType.Type
import           Data.Aeson.AutoType.Extract
import           Data.Aeson.AutoType.Format
import           Data.Aeson.AutoType.CodeGen
import           Data.Aeson.AutoType.Util
import           HFlags


instance Arbitrary Text where
  arbitrary = Text.pack  <$> sized (`vectorOf` alphabetic)
    where
      alphabetic = choose ('a', 'z')

instance (Arbitrary a) => Arbitrary (V.Vector a) where
  arbitrary = V.fromList <$> arbitrary

instance (Arbitrary v) => Arbitrary (Map.HashMap Text v) where
  arbitrary = makeMap <$> arbitrary
    where
      makeMap  = Map.fromList . nubBy ((==) `on` fst) . sortOn fst

instance Arbitrary Scientific where
  arbitrary = scientific <$> arbitrary <*> arbitrary

-- TODO: top value has to be complex: Object or Array
instance Arbitrary Value where
  arbitrary = sized arb
    where
      arb n | n < 0 = error "Negative size!"
      arb 0         = return Null
      arb 1         = oneof                          simpleGens
      arb i         = oneof $ complexGens (i - 1) ++ simpleGens
      simpleGens    = [Number <$> arbitrary
                      ,Bool   <$> arbitrary
                      ,String <$> arbitrary]

complexGens i = [Object . Map.fromList <$> resize i arbitrary,
                 Array                 <$> resize i arbitrary]

arbitraryTopValue :: Gen Value
arbitraryTopValue = sized $ oneof . complexGens

fst3 ::  (t, t1, t2) -> t
fst3 (a, _, _) = a

-- * Command line flags
defineFlag "z:size"            (10     :: Int)        "Size of generated elements"
defineFlag "s:stem"            ("Test" :: FilePath)   "Test filename stem"
defineFlag "c:count"           (100    :: Int)        "Number of test cases to generate."
defineFlag "o:outputFilename"   defaultOutputFilename "Write output to the given file"
defineFlag "suggest"            True                  "Suggest candidates for unification"
defineFlag "autounify"          True                  "Automatically unify suggested candidates"
defineFlag "t:test"             False                 "Try to run generated parser after"
defineFlag "d:debug"            False                 "Set this flag to see more debugging info"
defineFlag "fakeFlag"           True                  "Ignore this flag - it doesn't exist!!! It is workaround to library problem."

-- Tracing is switched off:
myTrace :: String -> IO ()
myTrace msg = if flags_debug
                then putStrLn msg
                else return ()

-- | Report an error to error output.
report   :: Text -> IO ()
report    = Text.hPutStrLn stderr

-- | Report an error and terminate the program.
fatal    :: Text -> IO ()
fatal msg = do report msg
               exitFailure

-- | Read JSON and extract @Type@ information from it.
extractTypeFromJSONFile :: FilePath -> IO (Maybe Type)
extractTypeFromJSONFile inputFilename =
      withFileOrHandle inputFilename ReadMode stdin $ \hIn ->
        -- First we decode JSON input into Aeson's Value type
        do bs <- BSL.hGetContents hIn
           Text.hPutStrLn stderr $ "Processing " `Text.append` Text.pack (show inputFilename)
           myTrace ("Decoded JSON: " ++ pretty (decode bs :: Maybe Value))
           case decode bs of
             Nothing -> do report $ "Cannot decode JSON input from " `Text.append` Text.pack (show inputFilename)
                           return Nothing
             Just v  -> do -- If decoding JSON was successful...
               -- We extract type structure from the JSON value.
               let t        = extractType v
               myTrace $ "Type: " ++ pretty t
               return $ Just t

-- | Take a set of JSON input filenames, Haskell output filename, and generate module parsing these JSON files.
generateTestJSONs :: IO ()
generateTestJSONs = do
    results <- forM (zip inputFilenames outputFilenames) $ \(inputFilename, outputFilename) -> do
      jsonValue :: Value <- generate $ resize flags_size arbitraryTopValue
      BSL.writeFile inputFilename $ encode jsonValue
      -- Read type from each file
      typeForEachFile  <- catMaybes <$> mapM extractTypeFromJSONFile [inputFilename]
      -- Unify all input types
      when (null typeForEachFile) $ do
        report "No valid JSON input file..."
        exitFailure
      let finalType = foldr1 unifyTypes typeForEachFile
      -- We split different dictionary labels to become different type trees (and thus different declarations.)
      let splitted = splitTypeByLabel "TopLevel" finalType
      --myTrace $ "SPLITTED: " ++ pretty splitted
      assertM $ not $ any hasNonTopTObj $ Map.elems splitted
      -- We compute which type labels are candidates for unification
      let uCands = unificationCandidates splitted
      myTrace $ "CANDIDATES:\n" ++ pretty uCands
      when flags_suggest $ forM_ uCands $ \cs -> do
                             putStr "-- "
                             Text.putStrLn $ "=" `Text.intercalate` cs
      -- We unify the all candidates or only those that have been given as command-line flags.
      let unified = if flags_autounify
                      then unifyCandidates uCands splitted
                      else splitted
      myTrace $ "UNIFIED:\n" ++ pretty unified
      -- We start by writing module header
      writeHaskellModule outputFilename unified
      if flags_test
        then 
          (==ExitSuccess) <$> system (unwords $ ["runghc", outputFilename] ++ inputFilenames)
        else
          return True
    putStrLn $ "Successfully generated "      ++ show (length results) ++
               " JSON files, out of planned " ++ show flags_count  ++ " cases."
  where
    makeInputFilename  = (<.>".json") . (flags_stem ++) . show
    makeOutputFilename = (<.>".hs")   . (flags_stem ++) . show
    inputFilenames     = map makeInputFilename  [1..flags_count]
    outputFilenames    = map makeOutputFilename [1..flags_count]

main :: IO ()
main = do filenames <- $initHFlags "testJSON -- automatic test JSON generation"
          -- TODO: should integrate all inputs into single type set!!!
          generateTestJSONs

