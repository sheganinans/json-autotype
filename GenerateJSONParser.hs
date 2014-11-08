{-# LANGUAGE TemplateHaskell, ScopedTypeVariables, OverloadedStrings #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}
module Main where

import           Control.Applicative
import           Data.Maybe
import           System.Exit
import           System.IO                 (stdin, stderr, stdout, IOMode(..))
import           System.FilePath           (splitExtension)
import           Control.Monad             (forM_, when)
import           Control.Exception(assert)
import qualified Data.ByteString.Lazy.Char8 as BSL
import qualified Data.HashMap.Strict        as Map
import           Data.Aeson
import qualified Data.Text                  as Text
import qualified Data.Text.IO               as Text
import           Data.Text                 (Text)

import           Data.Aeson.AutoType.Type
import           Data.Aeson.AutoType.Extract
import           Data.Aeson.AutoType.Format
import           CLI
import           HFlags

fst3 ::  (t, t1, t2) -> t
fst3 (a, _, _) = a

assertM ::  Monad m => Bool -> m ()
assertM v = assert v $ return ()

capitalize :: Text -> Text
capitalize input = Text.toUpper (Text.take 1 input)
                   `Text.append` Text.drop 1 input

header :: Text -> Text
header moduleName = Text.unlines [
   "{-# LANGUAGE TemplateHaskell, ScopedTypeVariables #-}"
  ,Text.concat ["module ", capitalize moduleName, " where"]
  ,""
  ,"import           System.Exit        (exitFailure, exitSuccess)"
  ,"import           System.IO          (stderr, hPutStrLn)"
  ,"import qualified Data.ByteString.Lazy.Char8 as BSL"
  ,"import           System.Environment (getArgs)"
  ,"import           Control.Monad      (forM_)"
  ,"import           Data.Text (Text)"
  ,"import           Data.Aeson(decode, Value(..), FromJSON(..),"
  ,"                            (.:), (.:?), (.!=))"
  ,"import           Data.Aeson.TH" 
  ,""]

epilogue :: Text
epilogue          = Text.unlines
  [""
  ,"parse :: FilePath -> IO TopLevel"
  ,"parse filename = do input <- BSL.readFile filename"
  ,"                    case decode input of"
  ,"                      Nothing -> fatal $ case (decode input :: Maybe Value) of"
  ,"                                           Nothing -> \"Invalid JSON file: \"     ++ filename"
  ,"                                           Just v  -> \"Mismatched JSON value: \" ++ show v"
  ,"                      Just r  -> return r"
  ,"  where"
  ,"    fatal :: String -> IO a"
  ,"    fatal msg = do hPutStrLn stderr msg"
  ,"                   exitFailure"
  ,""
  ,"main :: IO ()"
  ,"main = do filenames <- getArgs"
  ,"          forM_ filenames (\\f -> parse f >>= print)"
  ,"          exitSuccess"
  ,""]

-- Write a Haskell module to an output file, or stdout if `-` filename is given.
writeHaskellModule :: FilePath -> Map.HashMap Text Type -> IO ()
writeHaskellModule outputFilename types =
    withFileOrHandle outputFilename WriteMode stdout $ \hOut -> do
      assertM (extension == ".hs")
      Text.hPutStrLn hOut $ header $ Text.pack moduleName
      -- We write types as Haskell type declarations to output handle
      Text.hPutStrLn hOut $ displaySplitTypes types
      Text.hPutStrLn hOut   epilogue
  where
    (moduleName, extension) = splitExtension $
                                if     outputFilename == "-"
                                  then defaultOutputFilename
                                  else outputFilename


-- * Command line flags
defineFlag "outputFilename"  (defaultOutputFilename :: FilePath) "Write output to the given file"
defineFlag "suggest"         True                                "Suggest candidates for unification"
defineFlag "autounify"       True                                "Automatically unify suggested candidates"
defineFlag "fakeFlag"        True                                "Ignore this flag - it doesn't exist!!!"

-- Tracing is switched off:
myTrace :: String -> IO ()
--myTrace _msg = return ()
myTrace = putStrLn 

-- | Report an error to error output.
report   :: Text -> IO ()
report    = Text.hPutStrLn stderr

-- | Report an error and terminate the program.
fatal    :: Text -> IO ()
fatal msg = do report msg
               exitFailure

extractTypeFromJSONFile :: FilePath -> IO (Maybe Type)
extractTypeFromJSONFile inputFilename =
      withFileOrHandle inputFilename ReadMode stdin $ \hIn ->
        -- First we decode JSON input into Aeson's Value type
        do bs <- BSL.hGetContents hIn
           Text.hPutStrLn stderr $ "Processing " `Text.append` Text.pack (show inputFilename)
           myTrace ("Decoded JSON: " ++ show (decode bs :: Maybe Value))
           case decode bs of
             Nothing -> do report $ "Cannot decode JSON input from " `Text.append` Text.pack (show inputFilename)
                           return Nothing
             Just v  -> do -- If decoding JSON was successful...
               -- We extract type structure from the JSON value.
               let t        = extractType v
               myTrace $ "type: " ++ show t
               return $ Just t

-- | Take a set of JSON input filenames, Haskell output filename, and generate module parsing these JSON files.
generateHaskellFromJSONs :: [FilePath] -> FilePath -> IO ()
generateHaskellFromJSONs inputFilenames outputFilename =
    forM_ inputFilenames $ \inputFilename -> do
      -- Read type from each file
      typeForEachFile  <- catMaybes <$> mapM extractTypeFromJSONFile inputFilenames
      -- Unify all input types
      let finalType = foldr1 unifyTypes typeForEachFile
      -- We split different dictionary labels to become different type trees (and thus different declarations.)
      let splitted = splitTypeByLabel "TopLevel" finalType
      myTrace $ "splitted: " ++ show splitted
      assertM $ not $ any hasNonTopTObj $ Map.elems splitted
      -- We compute which type labels are candidates for unification
      let uCands = unificationCandidates splitted
      myTrace $ "candidates: " ++ show uCands
      when flags_suggest $ forM_ uCands $ \cs -> do
                             putStr "-- "
                             Text.putStrLn $ "=" `Text.intercalate` cs
      -- We unify the all candidates or only those that have been given as command-line flags.
      let unified = if flags_autounify
                      then unifyCandidates uCands splitted
                      else splitted
      myTrace $ "unified: " ++ show unified
      -- We start by writing module header
      writeHaskellModule outputFilename unified

main :: IO ()
main = do filenames <- $initHFlags "json-autotype -- automatic type and parser generation from JSON"
          -- TODO: should integrate all inputs into single type set!!!
          generateHaskellFromJSONs filenames flags_outputFilename
