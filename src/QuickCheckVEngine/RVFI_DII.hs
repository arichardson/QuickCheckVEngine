--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- Copyright (c) 2018 Matthew Naylor
-- Copyright (c) 2018 Jonathan Woodruff
-- Copyright (c) 2018, 2020 Alexandre Joannou
-- All rights reserved.
--
-- This software was developed by SRI International and the University of
-- Cambridge Computer Laboratory (Department of Computer Science and
-- Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
-- DARPA SSITH research programme.
--
-- This software was partly developed by the University of Cambridge
-- Computer Laboratory as part of the Partially-Ordered Event-Triggered
-- Systems (POETS) project, funded by EPSRC grant EP/N031768/1.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
-- 1. Redistributions of source code must retain the above copyright
--    notice, this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright
--    notice, this list of conditions and the following disclaimer in the
--    documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
-- OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
-- LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
-- OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
-- SUCH DAMAGE.
--

{-|
    Module      : QuickCheckVEngine.RVFI_DII
    Description : The RVFI-DII interface

    This module re-exports the 'QuickCheckVEngine.RVFI_DII.RVFI' and
    'QuickCheckVEngine.RVFI_DII.DII' modules, and provides functions to send and
    receive 'DII_Packet's and 'RVFI_Packet's over a 'Socket'.
-}

module QuickCheckVEngine.RVFI_DII (
  module QuickCheckVEngine.RVFI_DII.RVFI
, module QuickCheckVEngine.RVFI_DII.DII
, sendDIIPacket
, sendDIITrace
, recvRVFIPacket
, recvRVFITrace
) where

import QuickCheckVEngine.RVFI_DII.RVFI
import QuickCheckVEngine.RVFI_DII.DII

import Data.Int
import Data.Binary
import Control.Monad
import Network.Socket
import Network.Socket.ByteString.Lazy
import qualified Data.ByteString.Lazy as BS

-- | Send a single 'DII_Packet'
sendDIIPacket :: Socket -> DII_Packet -> IO ()
sendDIIPacket sckt inst = sendAll sckt $ BS.reverse (encode inst)

-- | Send an instruction trace (a '[DII_Packet]')
sendDIITrace :: Socket -> [DII_Packet] -> IO ()
sendDIITrace sckt trace = mapM_ (sendDIIPacket sckt) trace

-- | Receive a single 'RVFI_Packet'
recvRVFIPacket :: Socket -> IO RVFI_Packet
recvRVFIPacket sckt = do msg <- recvBlking sckt 88
                         return $ decode (BS.reverse msg)

-- | Receive an execution trace (a '[RVFI_Packet]')
recvRVFITrace :: Socket -> Bool -> IO [RVFI_Packet]
recvRVFITrace sckt doLog = do rvfiPkt <- recvRVFIPacket sckt
                              when doLog $ putStrLn $ "\t" ++ show rvfiPkt
                              if rvfiIsHalt rvfiPkt
                                 then return [rvfiPkt]
                                 else do morePkts <- recvRVFITrace sckt doLog
                                         return (rvfiPkt:morePkts)

-- Internal helpers (not exported):
--------------------------------------------------------------------------------

-- | Receive a fixed number of bytes
recvBlking :: Socket -> Int64 -> IO BS.ByteString
recvBlking sckt 0 = return BS.empty
recvBlking sckt n = do received  <- Network.Socket.ByteString.Lazy.recv sckt n
                       remainder <- recvBlking sckt (n - BS.length received)
                       return $ BS.append received remainder
