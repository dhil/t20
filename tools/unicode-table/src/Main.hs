module Main where

import Data.Char
import Data.Char.Properties.Names (getCharacterName)

import Numeric (showHex)

type CharInfo = (Char, Int, String, GeneralCategory)

type Ident = String
type Value = String
data Exp = True          -- true
         | False         -- false
         | Var Ident     -- x
         | Hex String    -- 0xABCD
         | LE Exp Exp    -- E <= E'
         | GE Exp Exp    -- E >= E'
         | And Exp Exp   -- E && E'
         | Or Exp Exp    -- E || E'
         deriving Show

data Term = Let Ident Value      -- x = V
          | Fun Ident Ident Term -- f x . M
          | If Exp Term Term     -- if E then tt else ff
          | Return Exp           -- return E
          deriving Show

replace :: Eq a => a -> a -> [a] -> [a]
replace a b = map $ \c -> if c == a then b else c

-- | Attempts to find a human readable name for control characters.
getHumanCtrlName :: Char -> Maybe String
getHumanCtrlName c = case c of
             '\x0000' -> Just "NULL"
             '\x0002' -> Just "START OF HEADING"
             '\x0003' -> Just "END OF TEXT"
             '\x0004' -> Just "END OF TRANSMISSION"
             '\x0005' -> Just "ENQUIRY"
             '\x0006' -> Just "ACKNOWLEDGE"
             '\x0007' -> Just "BELL"
             '\x0008' -> Just "BACKSPACE"
             '\x0009' -> Just "CHARACTER TABULATION"
             '\x000A' -> Just "LINE FEED"
             '\x000B' -> Just "LINE TABULATION"
             '\x000C' -> Just "FORM FEED"
             '\x000D' -> Just "CARRIAGE RETURN"
             '\x000E' -> Just "SHIFT OUT"
             '\x000F' -> Just "SHIFT IN"
             '\x0010' -> Just "DATA LINK ESCAPE"
             '\x0011' -> Just "DEVICE CONTROL ONE"
             '\x0012' -> Just "DEVICE CONTROL TWO"
             '\x0013' -> Just "DEVICE CONTROL THREE"
             '\x0014' -> Just "DEVICE CONTROL FOUR"
             '\x0015' -> Just "NEGATIVE ACKNOWLEDGE"
             '\x0016' -> Just "SYNCHRONOUS IDLE"
             '\x0017' -> Just "END OF TRANSMISSION BLOCK"
             '\x0018' -> Just "CANCEL"
             '\x0019' -> Just "END OF MEDIUM"
             '\x001A' -> Just "SUBSTITUTE"
             '\x001B' -> Just "ESCAPE"
             '\x001C' -> Just "INFORMATION SEPARATOR FOUR"
             '\x001D' -> Just "INFORMATION SEPARATOR THREE"
             '\x001E' -> Just "INFORMATION SEPARATOR TWO"
             '\x001F' -> Just "INFORMATION SEPARATOR ONE"
             '\x007F' -> Just "DELETE"
             '\x0082' -> Just "BREAK PERMITTED HERE"
             '\x0083' -> Just "NO BREAK HERE"
             '\x0084' -> Just "INDEX"
             '\x0085' -> Just "NEW LINE"
             '\x0086' -> Just "START OF SELECTED AREA"
             '\x0087' -> Just "END OF SELECTED AREA"
             '\x0088' -> Just "CHARACTER TABULATION SET"
             '\x0089' -> Just "CHARACTER TABULATION WITH JUSTIFICATION"
             '\x008A' -> Just "LINE TABULATION SET"
             '\x008B' -> Just "PARTIAL LINE FORWARD"
             '\x008C' -> Just "PARTIAL LINE BACKWARD"
             '\x008D' -> Just "REVERSE LINE FEED"
             '\x008E' -> Just "SINGLE SHIFT TWO"
             '\x008F' -> Just "SINGLE SHIFT THREE"
             '\x0090' -> Just "DEVICE CONTROL STRING"
             '\x0091' -> Just "PRIVATE USE ONE"
             '\x0092' -> Just "PRIVATE USE TWO"
             '\x0093' -> Just "SET TRASMIT STATE"
             '\x0094' -> Just "CANCEL CHARACTER"
             '\x0095' -> Just "MESSAGE WAITING"
             '\x0096' -> Just "START OF GUARDED AREA"
             '\x0097' -> Just "END OF GUARDED AREA"
             '\x0098' -> Just "START OF STRING"
             '\x009A' -> Just "SINGLE CHARACTER INTRODUCER"
             '\x009B' -> Just "CONTROL SEQUENCE INTRODUCER"
             '\x009C' -> Just "STRING TERMINATOR"
             '\x009D' -> Just "OPERATING SYSTEM COMMAND"
             '\x009E' -> Just "PRIVACY MESSAGE"
             '\x009F' -> Just "APPLICATION PROGRAM COMMAND"
             _        -> Nothing

pad :: Int -> Char -> String -> String
pad n c s
  | length s < n = replicate (n - length s) c ++ s
  | otherwise = s

hexCode :: Char -> String
hexCode c = "0x" ++ hex
  where hex = pad 4 '0' (showHex (ord c) "")

uName :: Char -> String
uName c = capitalise ("U" ++ hexName)
  where capitalise = map toUpper
        hexName = pad 4 '0' (showHex (ord c) "")


alternatives :: Char -> [String]
alternatives c = uName c : tail
  where tail = alt c ++ human c
        human c = case getCharacterName c of
                  "<control>" ->
                    case getHumanCtrlName c of
                      Nothing -> []
                      Just x  -> pure x
                  name -> pure name
        alt c = case c of
                 '\x0009' -> ["TAB", "HT"]
                 '\x000A' -> ["LF", "NL"]
                 '\x000C' -> pure "FF"
                 '\x000D' -> pure "CR"
                 '\x0021' -> pure "BANG"
                 '\x0022' -> pure "QUOTE"
                 '\x0023' -> pure "HASH"
                 '\x0024' -> pure "DOLLAR"
                 '\x0025' -> pure "PERCENT"
                 '\x0027' -> pure "SINGLE QUOTE"
                 '\x0028' -> pure "LPAREN"
                 '\x0029' -> pure "RPAREN"
                 '\x002B' -> pure "PLUS"
                 '\x002D' -> pure "DASH"
                 '\x002E' -> pure "DOT"
                 '\x002F' -> pure "SLASH"
                 '\x0030' -> pure "ZERO"
                 '\x0031' -> pure "ONE"
                 '\x0032' -> pure "TWO"
                 '\x0033' -> pure "THREE"
                 '\x0034' -> pure "FOUR"
                 '\x0035' -> pure "FIVE"
                 '\x0036' -> pure "SIX"
                 '\x0037' -> pure "SEVEN"
                 '\x0038' -> pure "EIGHT"
                 '\x0039' -> pure "NINE"
                 '\x003C' -> pure "LT"
                 '\x003D' -> pure "EQ"
                 '\x003E' -> pure "GT"
                 '\x0040' -> pure "AT"
                 '\x005B' -> pure "LBRACKET"
                 '\x005C' -> pure "BACKSLASH"
                 '\x005D' -> pure "RBRACKET"
                 '\x005E' -> ["CARET", "HAT"]
                 '\x007B' -> pure "LBRACE"
                 '\x007C' -> ["BAR", "PIPE"]
                 '\x007D' -> pure "RBRACE"
                 c        ->
                   if (c >= '\x0041' && c <= '\x005A') || (c >= '\x0061' && c <= '\x007A')
                   then pure [c]
                   else []

-- | Functions
between :: Char -> Char -> Ident -> Exp
between l u v = And (GE (Var v) (Hex $ hexCode l)) (LE (Var v) (Hex $ hexCode u))

isLetter :: Term
isLetter = Fun "IS LETTER" "c" (Return (between 'A' 'Z' "c"))

-- | Every unicode character.
unicodes :: [Char]
unicodes = [minBound..]

-- | Associates an ASCII compliant name with the integer code of each
-- unicode character.
namesAndCodes :: [(String, Int)]
namesAndCodes = undefined

info :: Char -> CharInfo
info c = (c, ord c, getCharacterName c, generalCategory c)

table :: [CharInfo]
table = map info $ take 100 unicodes

main :: IO ()
main = do
  putStrLn "hello world"
