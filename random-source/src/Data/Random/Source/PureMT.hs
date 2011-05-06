{-# LANGUAGE CPP #-}
{-# LANGUAGE TemplateHaskell, GADTs #-}
{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE MultiParamTypeClasses, FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE UndecidableInstances #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

-- |This module provides functions useful for implementing new 'MonadRandom'
-- and 'RandomSource' instances for state-abstractions containing 'PureMT'
-- values (the pure pseudorandom generator provided by the
-- mersenne-random-pure64 package), as well as instances for some common
-- cases.
-- 
-- A 'PureMT' generator is immutable, so 'PureMT' by itself cannot be a 
-- 'RandomSource' (if it were, it would always give the same \"random\"
-- values).  Some form of mutable state must be used, such as an 'IORef',
-- 'State' monad, etc..  A few default instances are provided by this module
-- along with more-general functions ('getRandomPrimFromMTRef' and
-- 'getRandomPrimFromMTState') usable as implementations for new cases
-- users might need.
module Data.Random.Source.PureMT 
    ( PureMT, newPureMT, pureMT
    ) where

import Data.Random.Source
import Data.Random.Source

import System.Random.Mersenne.Pure64

import Data.StateRef

import Control.Monad.State
#ifndef MTL2
import qualified Control.Monad.ST.Strict as S
#endif
import qualified Control.Monad.State.Strict as S

{-# INLINE withMTRef #-}
withMTRef :: (Monad m, ModifyRef sr m PureMT) => (PureMT -> (t, PureMT)) -> sr -> m t
withMTRef thing ref = atomicModifyReference ref $ \(!oldMT) -> 
    case thing oldMT of (!w, !newMT) -> (newMT, w)

{-# INLINE withMTState #-}
withMTState :: MonadState PureMT m => (PureMT -> (t, PureMT)) -> m t
withMTState thing = do
    !mt <- get
    let (!ws, !newMt) = thing mt
    put newMt
    return ws

#ifndef MTL2

$(monadRandom
    [d| instance MonadRandom (State PureMT) |]
    [d|
        getWord64 = withMTState randomWord64
        getDouble = withMTState randomDouble
     |])

$(monadRandom
    [d| instance MonadRandom (S.State PureMT) |]
    [d|
        getWord64 = withMTState randomWord64
        getDouble = withMTState randomDouble
     |])

#endif

$(randomSource
    [d| instance (Monad m1, ModifyRef (Ref m2 PureMT) m1 PureMT) => RandomSource m1 (Ref m2 PureMT) |]
    [d|
        getWord64 = withMTRef randomWord64
        getDouble = withMTRef randomDouble
    |])

$(monadRandom
    [d| instance Monad m => MonadRandom (StateT PureMT m) |]
    [d|
        getWord64 = withMTState randomWord64
        getDouble = withMTState randomDouble
     |])

$(monadRandom
    [d| instance Monad m => MonadRandom (S.StateT PureMT m) |]
    [d|
        getWord64 = withMTState randomWord64
        getDouble = withMTState randomDouble
     |])

$(randomSource
    [d| instance (Monad m, ModifyRef (IORef PureMT) m PureMT) => RandomSource m (IORef PureMT) |]
    [d|
        getWord64 = withMTRef randomWord64
        getDouble = withMTRef randomDouble
     |])

$(randomSource
    [d| instance (Monad m, ModifyRef (STRef s PureMT) m PureMT) => RandomSource m (STRef s PureMT) |]
    [d|
        getWord64 = withMTRef randomWord64
        getDouble = withMTRef randomDouble
     |])

-- Note that this instance is probably a Bad Idea.  STM allows random variables
-- to interact in spooky quantum-esque ways - One transaction can 'retry' until
-- it gets a \"random\" answer it likes, which causes it to selectively consume 
-- entropy, biasing the supply from which other random variables will draw.
-- instance (Monad m, ModifyRef (TVar PureMT) m PureMT) => RandomSource m (TVar PureMT) where
--     {-# SPECIALIZE instance RandomSource IO  (TVar PureMT) #-}
--     {-# SPECIALIZE instance RandomSource STM (TVar PureMT) #-}
--     getRandomPrimFrom = getRandomPrimFromMTRef
    
