{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ExtendedDefaultRules #-}
{-# OPTIONS_GHC -fno-warn-type-defaults #-}
module Main where

import Control.Applicative ((<$>), (<*>))
import Control.Monad
import Shelly hiding (FilePath)
import Data.List (nub)
import Data.Text (Text)
import Data.Monoid
import qualified Data.Text as T
import Data.Yaml
default (T.Text)

data RegressionTest = RegressionTest
                      { name :: Text
                      , flags :: [Text]
                      , aptPackages :: [Text]
                      , specialSetup :: [Text]
                      } deriving (Eq, Show)

instance FromJSON RegressionTest where
  parseJSON (Object v) = RegressionTest <$> v .: "name"
                                        <*> v .:? "flags" .!= []
                                        <*> v .:? "apt-packages" .!= []
                                        <*> v .:? "special-setup" .!= []
  parseJSON _ = mzero

readTests :: FilePath -> IO [RegressionTest]
readTests fp = maybe [] id <$> decodeFile fp

checkApt :: Sh ()
checkApt = do
  apt <- which "apt-get"
  case apt of
    Nothing -> errorExit "Can't find apt-get.  Are you sure this is Ubuntu?"
    _ -> return ()

main :: IO ()
main = shelly $ verbosely $ do
  travis <- maybe False (const True) <$> get_env "TRAVIS"

  when travis checkApt
  tests <- liftIO $ readTests "tests/regression-suite.yaml"
  let pkgs = nub $ concatMap aptPackages tests
      specials = concatMap specialSetup tests

  when (not travis) $
    echo "ASSUMING THAT ALL NECESSARY LIBRARIES ALREADY INSTALLED!\n"

  when (travis && not (null pkgs)) $ do
    echo "INSTALLING APT PACKAGES\n"
    run_ "sudo" $ ["apt-get", "install", "-y"] ++ pkgs
    echo "\n"

  when (travis && not (null specials)) $ do
    echo "SPECIAL INSTALL STEPS\n"
    forM_ specials $ \s -> let (c:as) = T.words s in run_ (fromText c) as
    echo "\n"

  codes <- forM tests $ \t -> do
    let n = name t
        fs = concatMap (\f -> ["-f", f]) $ flags t
    echo $ "\nREGRESSION TEST: " <> n <> "\n"
    errExit False $ do
      run_ "cabal" $ ["install"] ++ fs ++ [n]
      lastExitCode

  if all (== 0) codes
    then exit 0
    else errorExit "SOME TESTS FAILED"
