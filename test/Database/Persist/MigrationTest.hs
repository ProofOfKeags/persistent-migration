{-# LANGUAGE OverloadedStrings #-}

module Database.Persist.MigrationTest where

import Control.Monad.Reader (runReaderT)
import Data.Text (Text)
import Database.Persist.Migration
import Database.Persist.Sql (SqlType(..))
import Database.Persist.TestUtils
import Test.Hspec.Expectations

getTestMigration :: Migration -> IO [Text]
getTestMigration migration = do
  testSqlBackend <- initSqlBackend
  runReaderT (getMigration testMigrateBackend migration) testSqlBackend

unit_basic_migration :: Expectation
unit_basic_migration = getTestMigration migration `shouldReturn` migrationText
  where
    migration =
      [ Operation (0 ~> 1) $
          CreateTable
            { ctName = "person"
            , ctSchema =
                [ Column "id" SqlInt32 []
                , Column "name" SqlString [NotNull]
                , Column "age" SqlInt32 [NotNull]
                , Column "alive" SqlBool [NotNull, Defaults "TRUE"]
                , Column "hometown" SqlInt64 [ForeignKey ("cities", "id")]
                ]
            , ctConstraints =
                [ PrimaryKey ["id"]
                , Unique ["name"]
                ]
            }
      , Operation (1 ~> 2) $ AddColumn "person" (Column "gender" SqlString []) Nothing
      , Operation (2 ~> 3) $ DropColumn ("person", "alive")
      , Operation (3 ~> 4) $ DropTable "person"
      ]
    migrationText =
      [ "CREATE TABLE person"
      , "ADD COLUMN person.gender"
      , "DROP COLUMN person.alive"
      , "DROP TABLE person"
      ]

unit_some_done :: Expectation
unit_some_done = withTestBackend $ do
  modifyTestBackend $ \backend -> backend{version = Just 1}
  getTestMigration migration `shouldReturn` migrationText
  where
    migration =
      [ Operation (0 ~> 1) $ CreateTable "person" [] []
      , Operation (1 ~> 2) $ DropTable "person"
      ]
    migrationText = ["DROP TABLE person"]

unit_all_done :: Expectation
unit_all_done = withTestBackend $ do
  modifyTestBackend $ \backend -> backend{version = Just 2}
  getTestMigration migration `shouldReturn` []
  where
    migration =
      [ Operation (0 ~> 1) $ CreateTable "person" [] []
      , Operation (1 ~> 2) $ DropTable "person"
      ]
