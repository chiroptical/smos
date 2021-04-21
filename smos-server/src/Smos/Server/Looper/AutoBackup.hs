{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module Smos.Server.Looper.AutoBackup where

import Control.Monad
import Control.Monad.IO.Class
import Control.Monad.Logger
import Control.Monad.Reader
import qualified Data.Text as T
import Data.Time
import Database.Persist
import Smos.Server.Backup
import Smos.Server.DB
import Smos.Server.Looper.Env

runAutoBackupLooper :: Looper ()
runAutoBackupLooper = do
  -- TODO do this in a conduit so we don't load all users
  userIds <- looperDB $ selectKeysList [] [Asc UserId]
  mapM_ autoBackupForUser userIds

autoBackupForUser :: UserId -> Looper ()
autoBackupForUser uid = do
  logDebugNS "auto-backup" $ "Checking for auto-backup for user " <> T.pack (show uid)
  compressionLevel <- asks looperEnvCompressionLevel
  mBackup <- looperDB $ selectFirst [BackupUser ==. uid] [Desc BackupTime]
  now <- liftIO getCurrentTime
  let shouldDoBackup = case mBackup of
        -- Never done a backup yet, do one now
        Nothing -> True
        -- Last backup
        Just (Entity _ Backup {..}) ->
          -- If the last backup was more than the interval ago, do another one now.
          diffUTCTime now backupTime >= autoBackupInterval

  when shouldDoBackup $ do
    logInfoNS "auto-backup" $ "Performing backup for user " <> T.pack (show uid)
    void $ looperDB $ doBackupForUser compressionLevel uid

autoBackupInterval :: NominalDiffTime
autoBackupInterval = nominalDay
