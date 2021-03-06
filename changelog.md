Changelog
=========
    1.0.11  Mar 2016

        * Updated to GHC 8.0


    1.0.10  Sep 2015

        * Fixed bug appeared with aeson 0.10 breaking change:
	https://github.com/bos/aeson/issues/287

    1.0.8  Sep 2015

        * Dependency bump for lens 4.13 and aeson 0.10.

    1.0.7  Jul 2015

        * Dependency bump for lens and vector.

    1.0.6  Jun 2015

        * Make lens and aeson versions consistent in the *.cabal file.

    1.0.3-1.0.5  Jun 2015

        * Bumped Aeson dependency up.
        * Tiny docs corrections.

    1.0.2  Jun 2015

        * Relaxed dependency for lens-4.11.

    1.0.1  Apr 2015

        * Relaxed dependency to lens-4.10.

    1.0  Apr 2015

        * First stable release.

    0.5  Apr 2015

        * Reduced name space pollution when generating code.
          Now all valid JSON test examples do work.
        * Corrected build failure on GHC 7.8.4

    0.4  Apr 2015

        * Release candidate for current functionality.

    0.3  Apr 2015

        * Passed all smallcheck/quickcheck tests.
        * Approaching release candidate.

    0.2.5.13  Apr 2015

        * Correctly handling lone option, not yet union with optionality.
          Fixed: #3.

    0.2.5.12  Apr 2015

        * Added typechecking before and after type unification.
        * Added shrink for more informative QuickCheck testing.
        * Tested mostly using GHC 7.10.

    0.2.5.11  Mar 2015

        * Add short versions of command line flags: -o, -d, and -t.

    0.2.5.10  Mar 2015

        * Bump up lens dependency.

    0.2.5.8  Mar 2015

        * Updated tests and build config.

    0.2.5.7  Mar 2015

        * Fixed documentation anchors, and unit test classification for failures.
    
    0.2.5.6  Mar 2015

        * Relaxed upper bounds for lens 4.8.
    
    0.2.5.5  Mar 2015

        * (Skipped this version number by mistake.)

    0.2.5.4  Dec 2014

        * Relaxed upper bounds for new lens.

    0.2.5.3  Dec 2014

        * Relaxed upper bounds again.

    0.2.5.2  Dec 2014

        * Updated metainfo, relaxed upper bounds for GHC 7.10.

    0.2.5.0  Nov 2014

        * Nicer union type syntax in Data.Aeson.AutoType.Alternative.

    0.2.4.0  Nov 2014

        * To assure proper treatment of unions,
          I make them with Data.Aeson.AutoType.Alternative type instead of Either.

    0.2.3.0  Nov 2014

        * Explicit JSON parser generation to avoid conflicts between Haskell keywords and field names.
        * Renaming of Haskell field names with a prefix of object name (data type.)

    0.2.2.0  Nov 2014

        * GenerateJSONParser may now take multiple input samples to produce single parser.
        * Fixed automated testing for all example files.

    0.2.1.4  Oct 2014

        * Added examples to the package distribution.

    0.2.1.3  Oct 2014

        * Cleaned up package.
        * Changelog in markdown format.

    0.2.1  Oct 2014

        * Added option to use it as a filter ('-' is accepted input name.)

    0.2.0  Oct 2014

        * First release to Hackage.
        * Handling of proper unions, and most examples.
        * Automatically tested on a wide range of example documents (see
        tests/)
        * Initial documentation in README.md.

    0.1.0  July 2014

	* First experiments uploaded to GitHub, and discussed to
	HackerSpace.SG.

