{-# LANGUAGE ExistentialQuantification, MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings, FlexibleInstances #-}
{-# OPTIONS_HADDOCK prune, not-home #-}
-- | Provides framework to interact with REST api gateways. Implementations specific to the
--   Discord API are provided in Network.Discord.Rest.Channel, Network.Discord.Rest.Guild,
--   and Network.Discord.Rest.User.
module Network.Discord.Rest
  ( module Network.Discord.Rest
  , module Network.Discord.Rest.Prelude
  , module Network.Discord.Rest.Channel
  , module Network.Discord.Rest.Guild
  , module Network.Discord.Rest.User
  ) where
    import Control.Monad (void)
    import Data.Maybe (fromJust)

    import Control.Lens
    import Control.Monad.Morph (lift)
    import Data.Aeson.Types
    import Data.Hashable
    import Network.URL
    import Network.Wreq
    import Pipes.Core

    import Network.Discord.Types as Dc
    import Network.Discord.Rest.Channel
    import Network.Discord.Rest.Guild
    import Network.Discord.Rest.Prelude
    import Network.Discord.Rest.User
    
    -- | Perform an API request.
    fetch :: (DoFetch a, Hashable a)
      => a -> Pipes.Core.Proxy X () c' c DiscordM Fetched
    fetch req = restServer +>> (request $ Fetch req)
    
    -- | Perform an API request, ignoring the response
    fetch' :: (DoFetch a, Hashable a)
      => a -> Pipes.Core.Proxy X () c' c DiscordM ()
    fetch' = void . fetch
    
    -- | Alternative method of interacting with the REST api
    withApi :: Pipes.Core.Client Fetchable Fetched DiscordM Fetched
      -> Effect DiscordM ()
    withApi inner = void $ restServer +>> inner
    
    -- | Provides a pipe to perform REST actions
    restServer :: Fetchable -> Server Fetchable Fetched DiscordM Fetched
    restServer req =
      lift (doFetch req) >>= respond >>= restServer

    -- | Obtains a new gateway to connect to.
    getGateway :: IO URL
    getGateway = do
      resp <- asValue =<< get (baseURL++"/gateway")
      return . fromJust $ importURL =<< parseMaybe getURL (resp ^. responseBody)
      where
        getURL :: Value -> Parser String
        getURL = withObject "url" (.: "url")
