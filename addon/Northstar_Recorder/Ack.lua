-- The uploader's acknowledgement (docs/RECORDING.md, "Ack file"). Northstar
-- Client rewrites this file with the highest chunk it has sent for each
-- install (one per WoW account; the accounts share this folder):
--   NorthstarRecorderAck = { ["<install id>"] = <seq>, ... }
-- and at the next login Recorder.lua deletes those chunks. It also writes
--   NorthstarRecorderShare = true|false
-- (sharing on in the client and not paused): true turns recording on at
-- login unless the player typed /psrec off, false turns it off. The release
-- ships it empty; a lost ack only means a chunk is uploaded twice.
NorthstarRecorderAck = nil
