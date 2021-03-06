-- -*-haskell-*-

module Cpp where

import Foreign
import Foreign.C
import System.IO.Unsafe (unsafePerformIO)

-- CPP directive
-- -
#define VERSION 2


-- conditional binding
-- -
#if (VERSION == 1)

-- this does not match the C definition
--
foo :: CInt -> CInt
foo = {#call pure fooC#}

#else

-- this does
--
foo :: CInt -> CInt -> CInt
foo = {#call pure fooC#}

#endif


-- C code
-- -
#c
int fooC (int, int);
#endc
