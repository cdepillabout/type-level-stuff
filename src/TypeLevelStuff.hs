{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveFoldable #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE EmptyCase #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE RoleAnnotations #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeInType #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

-- | Module    : Termonad.Config.Vec
-- Description : A small library of dependent types
-- Copyright   : (c) Dennis Gosnell, 2018
-- License     : BSD3
-- Stability   : experimental
-- Portability : POSIX
--
-- This is a small library of dependent types.  It provides indexed types like
-- 'Fin', 'Vec', and 'Matrix'.
--
-- This is mainly used in Termonad for "Termonad.Config.Colour" to represent
-- length-indexed colour lists.
--
-- This module implements a subset of the functionality from the abandoned
-- <http://hackage.haskell.org/package/type-combinators type-combinators> library.
-- Ideally this module would be split out to a separate package.
-- If you're interested in working on something like this, please see
-- <https://github.com/cdepillabout/termonad/issues/70 this issue> on Github.

module TypeLevelStuff
  -- ( Fin
  -- , I(I)
  -- , M(M)
  -- , N3
  -- , N24
  -- , N6
  -- , N8
  -- , Prod((:<), Ø)
  -- , Range
  -- , Vec
  -- , VecT((:+), (:*), ØV, EmptyV)
  -- , fin
  -- , genMatrix_
  -- , setSubmatrix
  -- , genVec_
  -- , vSetAt'
  -- )
    where

import Data.Distributive (Distributive(distribute))
import qualified Data.Foldable as Data.Foldable
import Data.Functor.Rep (Representable(..), apRep, bindRep, distributeRep, pureRep)
import Data.Kind (Type)
import Data.MonoTraversable (Element, MonoFoldable, MonoFunctor, MonoPointed)
import Data.Singletons.Prelude
import Data.Singletons.TH
import Text.Show (showParen, showString)
import Unsafe.Coerce (unsafeCoerce)

--------------------------
-- Misc VecT Operations --
--------------------------

-- TODO: These could be implemented?

-- data Range n l m = Range (IFin ('S n) l) (IFin ('S n) (l + m))
--   deriving (Show, Eq)

-- instance (Known (IFin ('S n)) l, Known (IFin ('S n)) (l + m))
--   => Known (Range n l) m where
--   type KnownC (Range n l) m
--     = (Known (IFin ('S n)) l, Known (IFin ('S n)) (l + m))
--   known = Range known known

-- updateRange :: Range n l m -> (Fin m -> f a -> f a) -> VecT n f a -> VecT n f a
-- updateRange = \case
--   Range  IFZ     IFZ    -> \_ -> id
--   Range (IFS l) (IFS m) -> \f -> onTail (updateRange (Range l m) f) \\ m
--   Range  IFZ    (IFS m) -> \f -> onTail (updateRange (Range IFZ m) $ f . FS)
--                                . onHead (f FZ) \\ m

-- setRange :: Range n l m -> VecT m f a -> VecT n f a -> VecT n f a
-- setRange r nv = updateRange r (\i _ -> index i nv)

-- updateSubmatrix
--   :: (ns ~ Fsts3 nlms, ms ~ Thds3 nlms)
--   => HList (Uncur3 Range) nlms -> (HList Fin ms -> a -> a) -> M ns a -> M ns a
-- updateSubmatrix = \case
--   Ø              -> \f -> (f Ø <$>)
--   Uncur3 r :< rs -> \f -> onMatrix . updateRange r $ \i ->
--     asM . updateSubmatrix rs $ f . (i :<)

-- setSubmatrix
--   :: (ns ~ Fsts3 nlms, ms ~ Thds3 nlms)
--   => HList (Uncur3 Range) nlms -> M ms a -> M ns a -> M ns a
-- setSubmatrix rs sm = updateSubmatrix rs $ \is _ -> indexMatrix is sm

-----------
-- Peano --
-----------

$(singletons [d|

  data Peano = Z | S Peano deriving (Eq, Ord, Show)

  addPeano :: Peano -> Peano -> Peano
  addPeano Z a = a
  addPeano (S a) b = S (addPeano a b)

  subtractPeano :: Peano -> Peano -> Peano
  subtractPeano Z _ = Z
  subtractPeano a Z = a
  subtractPeano (S a) (S b) = subtractPeano a b

  multPeano :: Peano -> Peano -> Peano
  multPeano Z _ = Z
  multPeano (S a) b = addPeano (multPeano a b) b

  n0 :: Peano
  n0 = Z

  n1 :: Peano
  n1 = S n0

  n2 :: Peano
  n2 = S n1

  n3 :: Peano
  n3 = S n2

  n4 :: Peano
  n4 = S n3

  n5 :: Peano
  n5 = S n4

  n6 :: Peano
  n6 = S n5

  n7 :: Peano
  n7 = S n6

  n8 :: Peano
  n8 = S n7

  n9 :: Peano
  n9 = S n8

  n10 :: Peano
  n10 = S n9

  n24 :: Peano
  n24 = multPeano n4 n6

  instance Num Peano where
    (+) = addPeano

    (-) = subtractPeano

    (*) = multPeano

    abs = id

    signum Z = Z
    signum (S _) = S Z

    fromInteger n =
      if n < 0
        then error "Num Peano fromInteger: n is negative"
        else
          if n == 0 then Z else S (fromInteger (n - 1))
  |])

-- | This is a proof that if we know @'S' n@ is less than @'S' m@, then we
-- know @n@ is also less than @m@.
--
-- >>> ltSuccProof (sing :: Sing N4) (sing :: Sing N5)
-- Refl
ltSuccProof ::
     forall (n :: Peano) (m :: Peano) proxy. ('S n < 'S m) ~ 'True
  => proxy n
  -> proxy m
  -> (n < m) :~: 'True
ltSuccProof _ _ = unsafeCoerce (Refl :: Int :~: Int)

---------
-- Fin --
---------

data Fin :: Peano -> Type where
  FZ :: forall (n :: Peano). Fin ('S n)
  FS :: forall (n :: Peano). !(Fin n) -> Fin ('S n)

deriving instance Eq (Fin n)
deriving instance Ord (Fin n)
deriving instance Show (Fin n)

toIntFin :: Fin n -> Int
toIntFin FZ = 0
toIntFin (FS x) = succ $ toIntFin x

-- | Similar to 'ifin' but for 'Fin'.
--
-- >>> fin (sing :: Sing N5) (sing :: Sing N1) :: Fin N5
-- FS FZ
fin ::
     forall total n. (n < total) ~ 'True
  => Sing total
  -> Sing n
  -> Fin total
fin total n = toFinIFin $ ifin total n

-- | Similar to 'ifin_' but for 'Fin'.
--
-- >>> fin_ @N4 (sing :: Sing N2) :: Fin N4
-- FS (FS FZ)
fin_ ::
     forall total n. (SingI total, (n < total) ~ 'True)
  => Sing n
  -> Fin total
fin_ n = toFinIFin $ ifin_ n

data instance Sing (z :: Fin n) where
  SFZ :: Sing 'FZ
  SFS :: Sing x -> Sing ('FS x)

instance SingI 'FZ where
  sing = SFZ

instance SingI n => SingI ('FS n) where
  sing = SFS sing

instance SingKind (Fin n) where
  type Demote (Fin n) = Fin n
  fromSing :: forall (a :: Fin n). Sing a -> Fin n
  fromSing SFZ = FZ
  fromSing (SFS fin') = FS (fromSing fin')

  toSing :: Fin n -> SomeSing (Fin n)
  toSing FZ = SomeSing SFZ
  toSing (FS fin') =
    case toSing fin' of
      SomeSing n -> SomeSing (SFS n)

instance Show (Sing 'FZ) where
  show SFZ = "SFZ"

instance Show (Sing n) => Show (Sing ('FS n)) where
  showsPrec d (SFS n) =
    showParen (d > 10) $
    showString "SFS " . showsPrec 11 n

----------
-- IFin --
----------

data IFin :: Peano -> Peano -> Type where
  IFZ :: forall (n :: Peano). IFin ('S n) 'Z
  IFS :: forall (n :: Peano) (m :: Peano). !(IFin n m) -> IFin ('S n) ('S m)

deriving instance Eq   (IFin x y)
deriving instance Ord  (IFin x y)
deriving instance Show (IFin x y)

toFinIFin :: IFin n m -> Fin n
toFinIFin IFZ = FZ
toFinIFin (IFS n) = FS (toFinIFin n)

toIntIFin :: IFin n m -> Int
toIntIFin = toIntFin . toFinIFin

-- | Create an 'IFin'.
--
-- >>> ifin (sing :: Sing N5) (sing :: Sing N2) :: IFin N5 N2
-- IFS (IFS IFZ)
ifin ::
     forall total n. ((n < total) ~ 'True)
  => Sing total
  -> Sing n
  -> IFin total n
ifin (SS _) SZ = IFZ
ifin (SS total') (SS n') =
  IFS $
    case ltSuccProof n' total' of
      Refl -> ifin total' n'
ifin _ _ = error "ifin: pattern impossible but GHC doesn't realize it"

-- | Create an 'IFin', but take the total implicitly.
--
-- >>> ifin_ @N5 (sing :: Sing N3) :: IFin N5 N3
-- IFS (IFS (IFS IFZ))
ifin_ ::
     forall total n. (SingI total, (n < total) ~ 'True)
  => Sing n
  -> IFin total n
ifin_ = ifin sing

data instance Sing (z :: IFin n m) where
  SIFZ :: Sing 'IFZ
  SIFS :: Sing x -> Sing ('IFS x)

instance SingI 'IFZ where
  sing = SIFZ

instance SingI n => SingI ('IFS n) where
  sing = SIFS sing

instance SingKind (IFin n m) where
  type Demote (IFin n m) = IFin n m
  fromSing :: forall (a :: IFin n m). Sing a -> IFin n m
  fromSing SIFZ = IFZ
  fromSing (SIFS fin') = IFS (fromSing fin')

  toSing :: IFin n m -> SomeSing (IFin n m)
  toSing IFZ = SomeSing SIFZ
  toSing (IFS fin') =
    case toSing fin' of
      SomeSing n -> SomeSing (SIFS n)

instance Show (Sing 'IFZ) where
  show SIFZ = "SIFZ"

instance Show (Sing n) => Show (Sing ('IFS n)) where
  showsPrec d (SIFS n) =
    showParen (d > 10) $
    showString "SIFS " . showsPrec 11 n

-----------
-- HList --
-----------

data HList :: (k -> Type) -> [k] -> Type where
  EmptyHList :: HList f '[]
  (:<) :: forall (f :: k -> Type) (a :: k) (as :: [k]). f a -> HList f as -> HList f (a ': as)

infixr 6 :<

-- | Data constructor for ':<'.
pattern ConsHList :: (f a :: Type) -> HList f as -> HList f (a ': as)
pattern ConsHList fa hlist = fa :< hlist

---------
-- Vec --
---------

data Vec (n :: Peano) :: Type -> Type where
  EmptyVec :: Vec 'Z a
  (:*) :: !a -> !(Vec n a) -> Vec ('S n) a
  deriving anyclass MonoFoldable

infixr 6 :*

-- | Data constructor for ':*'.
pattern ConsVec :: (a :: Type) -> Vec n a -> Vec ('S n) a
pattern ConsVec a vec = a :* vec

deriving instance Eq a => Eq (Vec n a)
deriving instance Ord a => Ord (Vec n a)
deriving instance Show a => Show (Vec n a)

deriving instance Functor (Vec n)
deriving instance Foldable (Vec n)

instance MonoFunctor (Vec n a)

instance SingI n => MonoPointed (Vec n a)

instance SingI n => Applicative (Vec n) where
  pure a = replaceVec_ a

  (<*>) = apVec ($)

instance SingI n => Distributive (Vec n) where
  distribute :: Functor f => f (Vec n a) -> Vec n (f a)
  distribute = distributeRep

instance SingI n => Representable (Vec n) where
  type Rep (Vec n) = Fin n

  tabulate :: (Fin n -> a) -> Vec n a
  tabulate = genVec_

  index :: Vec n a -> Fin n -> a
  index = flip indexVec

instance SingI n => Monad (Vec n) where
  (>>=) :: Vec n a -> (a -> Vec n b) -> Vec n b
  (>>=) = bindRep

type instance Element (Vec n a) = a

genVec_ :: SingI n => (Fin n -> a) -> Vec n a
genVec_ = genVec sing

genVec :: SPeano n -> (Fin n -> a) -> Vec n a
genVec SZ _ = EmptyVec
genVec (SS n) f = f FZ :* genVec n (f . FS)

indexVec :: Fin n -> Vec n a -> a
indexVec FZ (a :* _) = a
indexVec (FS n) (_ :* vec) = indexVec n vec

singletonVec :: a -> Vec N1 a
singletonVec a = ConsVec a EmptyVec

replaceVec :: Sing n -> a -> Vec n a
replaceVec SZ _ = EmptyVec
replaceVec (SS n) a = a :* replaceVec n a

imapVec :: forall n a b. (Fin n -> a -> b) -> Vec n a -> Vec n b
imapVec _ EmptyVec = EmptyVec
imapVec f (a :* as) = f FZ a :* imapVec (\fin' vec -> f (FS fin') vec) as

replaceVec_ :: SingI n => a -> Vec n a
replaceVec_ = replaceVec sing

apVec :: (a -> b -> c) -> Vec n a -> Vec n b -> Vec n c
apVec _ EmptyVec _ = EmptyVec
apVec f (a :* as) (b :* bs) = f a b :* apVec f as bs

onHeadVec :: (a -> a) -> Vec ('S n) a -> Vec ('S n) a
onHeadVec f (a :* as) = f a :* as

dropVec :: Sing m -> Vec (m + n) a -> Vec n a
dropVec SZ vec = vec
dropVec (SS n) (_ :* vec) = dropVec n vec

takeVec :: IFin n m -> Vec n a -> Vec m a
takeVec IFZ _ = EmptyVec
takeVec (IFS n) (a :* vec) = a :* takeVec n vec

updateAtVec :: Fin n -> (a -> a) -> Vec n a -> Vec n a
updateAtVec FZ f (a :* vec)  = f a :* vec
updateAtVec (FS n) f (a :* vec)  = a :* updateAtVec n f vec

setAtVec :: Fin n -> a -> Vec n a -> Vec n a
setAtVec fin' a = updateAtVec fin' (const a)

-- | Create a 'Vec' of length @n@ where every element is @a@.
--
-- >>> replicateVec (sing @N3) 'd'
-- 'd' :* ('d' :* ('d' :* EmptyVec))
replicateVec :: Sing n -> a -> Vec n a
replicateVec SZ _ = EmptyVec
replicateVec (SS n) a = ConsVec a $ replicateVec n a

-- | Just like 'replicateVec' but take the length argument implicitly.
--
-- >>> replicateVec_ @N2 "hello"
-- "hello" :* ("hello" :* EmptyVec)
replicateVec_ :: forall n a. SingI n => a -> Vec n a
replicateVec_ = replicateVec sing

fromListVec :: Sing n -> [a] -> Maybe (Vec n a)
fromListVec SZ _ = Just EmptyVec
fromListVec (SS _) [] = Nothing
fromListVec (SS n) (a:as) = do
  tailVec <- fromListVec n as
  pure $ ConsVec a tailVec

fromListVec_ :: SingI n => [a] -> Maybe (Vec n a)
fromListVec_ = fromListVec sing

unsafeFromListVec :: Sing n -> [a] -> Vec n a
unsafeFromListVec n as =
  case fromListVec n as of
    Just vec -> vec
    Nothing ->
      error $
        "unsafeFromListVec: couldn't create a length " <>
        show n <> " vector from the input list"

unsafeFromListVec_ :: SingI n => [a] -> Vec n a
unsafeFromListVec_ = unsafeFromListVec sing

------------
-- Matrix --
------------

-- | This is a type family that gives us arbitrarily-ranked matricies.
--
-- For example, this is a Matrix with three dimensions.  It is represented as a
-- 'Vec' containing a 'Vec' containing a 'Vec':
--
-- >>> Refl :: MatrixTF '[N3, N9, N7] Float :~: Vec N3 (Vec N9 (Vec N7 Float))
-- Refl
--
-- A Matrix with no dimensions represents a scalar value:
--
-- >>> Refl :: MatrixTF '[] Float :~: Float
-- Refl
type family MatrixTF (ns :: [Peano]) (a :: Type) :: Type where
  MatrixTF '[] a = a
  MatrixTF (n ': ns) a = Vec n (MatrixTF ns a)

newtype Matrix ns a = Matrix
  { unMatrix :: MatrixTF ns a
  }
  deriving anyclass (MonoFoldable)

type instance Element (Matrix ns a) = a

---------------------------------
-- Defunctionalization Symbols --
---------------------------------

type MatrixTFSym2 (ns :: [Peano]) (t :: Type) = (MatrixTF ns t :: Type)

data MatrixTFSym1 (ns :: [Peano]) (z :: TyFun Type Type)
  = forall (arg :: Type).  SameKind (Apply (MatrixTFSym1 ns) arg) (MatrixTFSym2 ns arg) => MatrixTFSym1KindInference

type instance Apply (MatrixTFSym1 l1) l2 = MatrixTF l1 l2

type role MatrixTFSym0 phantom

data MatrixTFSym0 (l :: TyFun [Peano] (Type ~> Type))
  = forall (arg :: [Peano]).  SameKind (Apply MatrixTFSym0 arg) (MatrixTFSym1 arg) => MatrixTFSym0KindInference

type instance Apply MatrixTFSym0 l = MatrixTFSym1 l

type role MatrixTFSym1 phantom phantom

----------------------
-- Matrix Functions --
----------------------

eqSingMatrix :: forall (peanos :: [Peano]) (a :: Type). Eq a => Sing peanos -> Matrix peanos a -> Matrix peanos a -> Bool
eqSingMatrix = compareSingMatrix (==) True (&&)

ordSingMatrix :: forall (peanos :: [Peano]) (a :: Type). Ord a => Sing peanos -> Matrix peanos a -> Matrix peanos a -> Ordering
ordSingMatrix = compareSingMatrix compare EQ f
  where
    f :: Ordering -> Ordering -> Ordering
    f EQ o = o
    f o _ = o

compareSingMatrix ::
     forall (peanos :: [Peano]) (a :: Type) (c :: Type)
   . (a -> a -> c)
  -> c
  -> (c -> c -> c)
  -> Sing peanos
  -> Matrix peanos a
  -> Matrix peanos a
  -> c
compareSingMatrix f _ _ SNil (Matrix a) (Matrix b) = f a b
compareSingMatrix _ empt _ (SCons SZ _) (Matrix EmptyVec) (Matrix EmptyVec) = empt
compareSingMatrix f empt combine (SCons (SS peanoSingle) moreN) (Matrix (a :* moreA)) (Matrix (b :* moreB)) =
  combine
    (compareSingMatrix f empt combine moreN (Matrix a) (Matrix b))
    (compareSingMatrix f empt combine (SCons peanoSingle moreN) (Matrix moreA) (Matrix moreB))

fmapSingMatrix :: forall (peanos :: [Peano]) (a :: Type) (b ::Type). Sing peanos -> (a -> b) -> Matrix peanos a -> Matrix peanos b
fmapSingMatrix SNil f (Matrix a) = Matrix $ f a
fmapSingMatrix (SCons SZ _) _ (Matrix EmptyVec) = Matrix EmptyVec
fmapSingMatrix (SCons (SS peanoSingle) moreN) f (Matrix (a :* moreA)) =
  let matA = fmapSingMatrix moreN f (Matrix a)
      matB = fmapSingMatrix (SCons peanoSingle moreN) f (Matrix moreA)
  in consMatrix matA matB

consMatrix :: Matrix ns a -> Matrix (n ': ns) a -> Matrix ('S n ': ns) a
consMatrix (Matrix a) (Matrix as) = Matrix $ ConsVec a as

toListMatrix ::
     forall (peanos :: [Peano]) (a :: Type).
     Sing peanos
  -> Matrix peanos a
  -> [a]
toListMatrix SNil (Matrix a) = [a]
toListMatrix (SCons SZ _) (Matrix EmptyVec) = []
toListMatrix (SCons (SS peanoSingle) moreN) (Matrix (a :* moreA)) =
  toListMatrix moreN (Matrix a) <> toListMatrix (SCons peanoSingle moreN) (Matrix moreA)

genMatrix ::
     forall (ns :: [Peano]) (a :: Type).
     Sing ns
  -> (HList Fin ns -> a)
  -> Matrix ns a
genMatrix SNil f = Matrix $ f EmptyHList
genMatrix (SCons (n :: SPeano foo) (ns' :: Sing oaoa)) f =
  Matrix $ (genVec n $ (gagaga :: Fin foo -> MatrixTF oaoa a) :: Vec foo (MatrixTF oaoa a))
  where
    gagaga :: Fin foo -> MatrixTF oaoa a
    gagaga faaa = unMatrix $ (genMatrix ns' $ byebye faaa :: Matrix oaoa a)

    byebye :: Fin foo -> HList Fin oaoa -> a
    byebye faaa = f . ConsHList faaa

genMatrix_ :: SingI ns => (HList Fin ns -> a) -> Matrix ns a
genMatrix_ = genMatrix sing

-- | Just like 'replicateVec' but for a 'Matrix'.
--
-- >>> replicateMatrix (sing @'[N2, N3]) 'b'
-- Matrix {unMatrix = ('b' :* ('b' :* ('b' :* EmptyVec))) :* (('b' :* ('b' :* ('b' :* EmptyVec))) :* EmptyVec)}
replicateMatrix :: Sing ns -> a -> Matrix ns a
replicateMatrix ns a = genMatrix ns (const a)

-- | Just like 'replicateMatrix', but take the length argument implicitly.
--
-- >>> replicateMatrix_ @'[N2,N2,N2] 0
-- Matrix {unMatrix = ((0 :* (0 :* EmptyVec)) :* ((0 :* (0 :* EmptyVec)) :* EmptyVec)) :* (((0 :* (0 :* EmptyVec)) :* ((0 :* (0 :* EmptyVec)) :* EmptyVec)) :* EmptyVec)}
replicateMatrix_ :: SingI ns => a -> Matrix ns a
replicateMatrix_ a = replicateMatrix sing a

indexMatrix :: HList Fin ns -> Matrix ns a -> a
indexMatrix EmptyHList (Matrix a) = a
indexMatrix (i :< is) (Matrix vec) = indexMatrix is $ Matrix (indexVec i vec)

imapMatrix :: forall (ns :: [Peano]) a b. Sing ns -> (HList Fin ns -> a -> b) -> Matrix ns a -> Matrix ns b
imapMatrix SNil f (Matrix a) = Matrix (f EmptyHList a)
imapMatrix (SCons _ ns) f matrix =
  onMatrixTF
    (imapVec (\fin' -> onMatrix (imapMatrix ns (\hlist -> f (ConsHList fin' hlist)))))
    matrix

imapMatrix_ :: SingI ns => (HList Fin ns -> a -> b) -> Matrix ns a -> Matrix ns b
imapMatrix_ = imapMatrix sing

onMatrixTF :: (MatrixTF ns a -> MatrixTF ms b) -> Matrix ns a -> Matrix ms b
onMatrixTF f (Matrix mat) = Matrix $ f mat

onMatrix :: (Matrix ns a -> Matrix ms b) -> MatrixTF ns a -> MatrixTF ms b
onMatrix f = unMatrix . f . Matrix

updateAtMatrix :: HList Fin ns -> (a -> a) -> Matrix ns a -> Matrix ns a
updateAtMatrix EmptyHList _ mat = mat
updateAtMatrix (n :< ns) f mat =
  onMatrixTF (updateAtVec n (onMatrix (updateAtMatrix ns f))) mat

setAtMatrix :: HList Fin ns -> a -> Matrix ns a -> Matrix ns a
setAtMatrix fins a = updateAtMatrix fins (const a)

-- | Multiply two matricies together.  This uses normal matrix multiplication,
-- not the Hadamard product.
--
-- When @m@ is 0, this produces a @n@ by @o@ matrix where all elements are 0.
--
-- >>> mat1 = replicateMatrix_ @'[N3, N0] 3
-- >>> mat2 = replicateMatrix_ @'[N0, N2] 3
-- >>> matrixMult (sing @N3) (sing @N0) (sing @N2) mat1 mat2
-- Matrix {unMatrix = (0 :* (0 :* EmptyVec)) :* ((0 :* (0 :* EmptyVec)) :* ((0 :* (0 :* EmptyVec)) :* EmptyVec))}
--
--
matrixMult
  :: forall n m o a
   . Num a
  => Sing n
  -> Sing m
  -> Sing o
  -> Matrix '[n, m] a
  -> Matrix '[m, o] a
  -> Matrix '[n, o] a
matrixMult n SZ o _ _ = replicateMatrix (doubletonList n o) 0
matrixMult n m o mat1 mat2 = genMatrix (doubletonList n o) go
  where
    go :: HList Fin '[n, o] -> a
    go (finN :< finO :< EmptyHList) = undefined

-- | Get the specified row of a matrix.
--
-- >>> let createVal finRow finCol = toIntFin finRow * 2 + toIntFin finCol
-- >>> let mat1 = genMatrix (sing @'[N3, N2]) (\(r :< c :< EmptyHList) -> createVal r c)
-- >>> mat1
-- Matrix {unMatrix = (0 :* (1 :* EmptyVec)) :* ((2 :* (3 :* EmptyVec)) :* ((4 :* (5 :* EmptyVec)) :* EmptyVec))}
--
-- Get the first row of a matrix:
--
-- >>> getRowMatrix FZ mat1
-- 0 :* (1 :* EmptyVec)
--
-- Get the third row of a matrix:
--
-- >>> getRowMatrix (FS (FS FZ)) mat1
-- 4 :* (5 :* EmptyVec)
getRowMatrix :: forall n m a. Fin n -> Matrix '[n, m] a -> Vec m a
getRowMatrix FZ (Matrix (v :* _)) = v
getRowMatrix (FS n) (Matrix (_ :* next)) = getRowMatrix n (Matrix next)


----------------------
-- Matrix Instances --
----------------------

deriving instance (Eq (MatrixTF ns a)) => Eq (Matrix ns a)

deriving instance (Ord (MatrixTF ns a)) => Ord (Matrix ns a)

deriving instance (Show (MatrixTF ns a)) => Show (Matrix ns a)

instance SingI ns => Functor (Matrix ns) where
  fmap :: (a -> b) -> Matrix ns a -> Matrix ns b
  fmap = fmapSingMatrix sing

instance SingI ns => Data.Foldable.Foldable (Matrix ns) where
  foldr :: (a -> b -> b) -> b -> Matrix ns a -> b
  foldr comb b = Data.Foldable.foldr comb b . toListMatrix sing

  toList :: Matrix ns a -> [a]
  toList = toListMatrix sing

instance SingI ns => Distributive (Matrix ns) where
  distribute :: Functor f => f (Matrix ns a) -> Matrix ns (f a)
  distribute = distributeRep

instance SingI ns => Representable (Matrix ns) where
  type Rep (Matrix ns) = HList Fin ns

  tabulate :: (HList Fin ns -> a) -> Matrix ns a
  tabulate = genMatrix_

  index :: Matrix ns a -> HList Fin ns -> a
  index = flip indexMatrix

instance Num a => Num (Matrix '[] a) where
  Matrix a + Matrix b = Matrix (a + b)

  Matrix a * Matrix b = Matrix (a * b)

  Matrix a - Matrix b = Matrix (a - b)

  abs (Matrix a) = Matrix (abs a)

  signum (Matrix a) = Matrix (signum a)

  fromInteger :: Integer -> Matrix '[] a
  fromInteger = Matrix . fromInteger

instance SingI ns => Applicative (Matrix ns) where
  pure :: a -> Matrix ns a
  pure = pureRep

  (<*>) :: Matrix ns (a -> b) -> Matrix ns a -> Matrix ns b
  (<*>) = apRep

instance SingI ns => Monad (Matrix ns) where
  (>>=) :: Matrix ns a -> (a -> Matrix ns b) -> Matrix ns b
  (>>=) = bindRep

----------------------
-- Helper Functions --
----------------------

-- | A @singleton@ function for type-level lists.
--
-- >>> singletonList (sing @N1)
-- SCons (SS SZ) SNil
singletonList :: forall x. Sing x -> Sing '[x]
singletonList x = SCons x SNil

-- | A function like 'singletonList', but creates a list with two elements.
--
-- >>> doubletonList (sing @N0) (sing @N2)
-- SCons SZ (SCons (SS (SS SZ)) SNil)
doubletonList :: Sing x -> Sing y -> Sing '[x, y]
doubletonList x y = singletonList x %++ singletonList y
