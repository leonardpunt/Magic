{-# LANGUAGE TypeOperators #-}

module IdList (

    -- * Types
    Id, IdList,

    -- * Construction
    empty, fromList,

    -- * Querying
    head, get, toList, ids,

    -- * Modifying
    set, remove, cons, cons', filter, shuffle,
    consM, removeM, shuffleM

  ) where

import Prelude hiding (filter, head)
import qualified Prelude

import Control.Arrow (second)
import Control.Monad.Random (MonadRandom)
import Control.Monad.State (MonadState)
import Data.Label.Pure ((:->))
import Data.Label.PureM (gets, puts)
import System.Random.Shuffle (shuffleM)



-- TYPES


newtype Id = Id Int
  deriving (Eq, Show, Ord)

data IdList a = IdList [(Id, a)] Id

instance Functor IdList where
  fmap = contents . fmap . second



-- CONSTRUCTION


empty :: IdList a
empty = IdList [] (Id 0)

fromList :: [a] -> IdList a
fromList = foldr (\x xs -> snd (cons' x xs)) empty



-- QUERYING


head :: IdList a -> Maybe (Id, a)
head (IdList (ix : _) _) = Just ix
head _ = undefined

get :: Id -> IdList a -> Maybe a
get i (IdList ixs _) = lookup i ixs

toList :: IdList a -> [(Id, a)]
toList (IdList ixs _) = ixs

ids :: IdList a -> [Id]
ids = map fst . toList



-- MODIFYING


set :: Id -> a -> IdList a -> IdList a
set i x (IdList ixs ni) = IdList (map f ixs) ni
  where
    f ix'@(i', _)
      | i == i'    = (i, x)
      | otherwise  = ix'

remove :: Id -> IdList a -> Maybe (a, IdList a)
remove i l =
  case get i l of
    Just x  -> Just (x, contents (Prelude.filter (\(i', _) -> i /= i')) l)
    Nothing -> Nothing

--pop :: IdList a -> Maybe (a, IdList a)
--pop (IdList ((_, x) : ixs) i) = Just (x, IdList ixs i)
--pop _ = Nothing

cons :: a -> IdList a -> IdList a
cons x xs = snd (cons' x xs)

cons' :: a -> IdList a -> (Id, IdList a)
cons' x (IdList ixs (Id i)) = (Id i, IdList ((Id i, x) : ixs) (Id (succ i)))

contents :: ([(Id, a)] -> [(Id, b)]) -> IdList a -> IdList b
contents f (IdList ixs i) = IdList (f ixs) i

filter :: (a -> Bool) -> IdList a -> [(Id, a)]
filter f = Prelude.filter (f . snd) . toList

shuffle :: MonadRandom m => IdList a -> m (IdList a)
shuffle (IdList ixs ni) = do
  ixs' <- shuffleM ixs
  return (IdList ixs' ni)

removeM :: MonadState s m => (s :-> IdList a) -> Id -> m (Maybe a)
removeM label i = do
  list <- gets label
  case remove i list of
    Just (x, list') -> do puts label list'; return (Just x)
    Nothing         -> return Nothing

consM :: MonadState s m => (s :-> IdList a) -> a -> m Id
consM label x = do
  list <- gets label
  let (i, list') = cons' x list
  puts label list'
  return i