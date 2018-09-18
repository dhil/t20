module Main where

import Data.Char
import Data.Char.Properties.Names (getCharacterName)
import Data.List (groupBy, intersperse, sort)
import Data.List.Split (splitOneOf)
import Data.Time

import Numeric (showHex)

import System.IO

type CharInfo = (Char, Int, String, GeneralCategory)

type Ident = String
type Value = String
data Exp = Var Ident     -- x
         | Hex String    -- 0xABCD
         | LE Exp Exp    -- E <= E'
         | EQ' Exp Exp    -- E == E'
         | And Exp Exp   -- E && E'
         | Or Exp Exp    -- E || E'
         deriving Show

data Term = Lam Ident Exp        -- \x . E
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
toHex :: Char -> Exp
toHex c = Hex $ hexCode c

(<=:) :: Exp -> Exp -> Exp
e <=: e' = LE e e'

(===) :: Exp -> Exp -> Exp
e === e' = EQ' e e'

(&&&) :: Exp -> Exp -> Exp
e &&& e' = And e e'

(|||) :: Exp -> Exp -> Exp
e ||| e' = Or e e'

between :: Char -> Char -> Exp -> Exp
between l u v = (l' <=: v) &&& (v <=: u')
  where l' = Hex $ hexCode l
        u' = Hex $ hexCode u

_isAsciiUppercase :: Exp -> Exp
_isAsciiUppercase var = between 'A' 'Z' var

isAsciiUpper' :: Term
isAsciiUpper' = Lam "c" (_isAsciiUppercase c)
  where c = Var "c"

_isAsciiLowercase :: Exp -> Exp
_isAsciiLowercase var = between 'a' 'z' var

isAsciiLower' :: Term
isAsciiLower' = Lam "c" (_isAsciiLowercase c)
  where c = Var "c"

_isAsciiLetter :: Exp -> Exp
_isAsciiLetter var =  _isAsciiLowercase var ||| _isAsciiUppercase var

isAsciiLetter' :: Term
isAsciiLetter' = Lam "c" (_isAsciiLetter c)
  where c = Var "c"

_isLatin1Uppercase :: Exp -> Exp
_isLatin1Uppercase var
  = between '\x0041' '\x005A' var
    ||| between '\x00C0' '\x00D6' var
    ||| between '\x00D8' '\x00DE' var

isLatin1Upper' :: Term
isLatin1Upper' = Lam "c" (_isLatin1Uppercase c)
  where c = Var "c"

_isLatin1Lowercase :: Exp -> Exp
_isLatin1Lowercase var
  = between '\x0061' '\x007A' var
    ||| between '\x00DF' '\x00F6' var
    ||| between '\x00F8' '\x00FF' var

isLatin1Lower' :: Term
isLatin1Lower' = Lam "c" (_isLatin1Lowercase c)
  where c = Var "c"

_isLatin1Letter :: Exp -> Exp
_isLatin1Letter var = _isLatin1Lowercase var ||| _isLatin1Uppercase var

isLatin1Letter' :: Term
isLatin1Letter' = Lam "c" (_isLatin1Letter c)
  where c = Var "c"

_isDigit :: Exp -> Exp
_isDigit var = between '0' '9' var

isDigit' :: Term
isDigit' = Lam "c" (_isDigit c)
  where c = Var "c"

isLetter' :: Term
isLetter' = Lam "c" ( _isAsciiLetter c ||| _isLatin1Letter c)
  where c = Var "c"

_isAsciiSpace :: Exp -> Exp
_isAsciiSpace var
  = var === space
    ||| var === nl
    ||| var === ht
    ||| var === cr
    ||| var === ff
    ||| var === lt
  where space = toHex ' '
        nl = toHex '\n'
        ht = toHex '\t'
        cr = toHex '\r'
        ff = toHex '\f'
        lt = toHex '\v'

isAsciiSpace' :: Term
isAsciiSpace' = Lam "c" (_isAsciiSpace c)
  where c = Var "c"

isAscii' :: Term
isAscii' = Lam "c" (Var "c" <=: toHex '\x0080')

isLatin1' :: Term
isLatin1' = Lam "c" (Var "c" <=: toHex '\x00FF')


_isSpaceChar :: Exp -> Exp
_isSpaceChar var
  = var === toHex '\x00A0'
    ||| var === toHex '\x1680'
    ||| var === toHex '\x180E'
    ||| (between '\x2000' '\x200B' var)
    ||| var === toHex '\x202F'
    ||| var === toHex '\x205F'
    ||| var === toHex '\x3000'
    ||| var === toHex '\xFEFF'

isSpace' :: Term
isSpace' = Lam "c" (_isAsciiSpace c ||| _isSpaceChar c)
  where c = Var "c"

functions :: [(String, Term)]
functions = [ ("IS ASCII LOWER", isAsciiLower')
            , ("IS ASCII UPPER", isAsciiUpper')
            , ("IS ASCII LETTER", isAsciiLetter')
            , ("IS ASCII SPACE", isAsciiSpace')
            , ("IS DIGIT", isDigit')
            , ("IS LATIN1 LOWER", isLatin1Lower')
            , ("IS LATIN1 UPPER", isLatin1Upper')
            , ("IS LATIN1 LETTER", isLatin1Letter')
            , ("IS LETTER", isLetter')
            , ("IS SPACE", isSpace') ]

-- | Every unicode character.
unicodes :: [Char]
unicodes = [minBound..]

-- | Category mapping
categoriesMapping :: [(GeneralCategory, [Char])]
categoriesMapping = hoistFst groups
  where pairs = sort $ map (\c -> (generalCategory c, c)) unicodes
        catEq (c, _) (c', _) = c == c'
        groups = groupBy catEq pairs
        hoistFst :: [[(a, b)]] -> [(a, [b])]
        hoistFst [] = []
        hoistFst (xs : xss) = (head . fst . unzip $ xs, snd . unzip $ xs) : hoistFst xss

categories :: [GeneralCategory]
categories = [minBound..]

-- | Associates an ASCII compliant name with the integer code of each
-- unicode character.
namesAndCodes :: [(String, Int)]
namesAndCodes = undefined

info :: Char -> CharInfo
info c = (c, ord c, getCharacterName c, generalCategory c)

table :: [CharInfo]
table = map info $ take 100 unicodes

-- | Dart backend
capitalise :: String -> String
capitalise (x : xs) = toUpper x : map toLower xs

camelCase :: String -> String
camelCase name = normalise parts
  where
    parts = splitOneOf "-_ " name
    normalise :: [String] -> String
    normalise [] = []
    normalise (x : xs) = concat $ (map toLower x : map capitalise xs)

toIdent :: String -> String
toIdent = camelCase


emitEnum :: Handle -> String -> [String] -> IO ()
emitEnum fh name members = do
  emit ("enum " ++ name ++ " {")
  emit (concat $ intersperse "," members)
  emit "}"
  where emit s = hPutStrLn fh s

emitConstant :: Handle -> String -> String -> IO ()
emitConstant fh name value
  = hPutStrLn fh ("const int " ++ name ++ " = " ++ value ++ ";")

emitTerm :: Handle -> String -> Term -> IO ()
emitTerm fh name (Lam b e) = do
  hPutStrLn fh ("bool " ++ name ++ "(" ++ b ++ ") {")
  hPutStr fh "  return "
  emitExp fh e
  hPutStrLn fh ";"
  hPutStrLn fh "}"

emitFun :: Handle -> (String, Term) -> IO ()
emitFun fh (name, def) = emitTerm fh (toIdent name) def

emitExp :: Handle -> Exp -> IO ()
emitExp fh (Var x) = hPutStr fh x
emitExp fh (Hex h) = hPutStr fh h
emitExp fh (LE lhs rhs) = emitBinaryOp fh lhs rhs "<="
emitExp fh (EQ' lhs rhs) = emitBinaryOp fh lhs rhs "=="
emitExp fh (And lhs rhs) = emitBinaryOp fh lhs rhs "&&"
emitExp fh (Or lhs rhs) = emitBinaryOp fh lhs rhs "||"

emitBinaryOp :: Handle -> Exp -> Exp -> String -> IO ()
emitBinaryOp fh lhs rhs op = do
  emitExp fh lhs
  hPutStr fh op
  emitExp fh rhs

emitComment :: Handle -> String -> IO ()
emitComment fh msg = hPutStrLn fh ("// " ++ msg)

emitHeader :: Handle -> IO ()
emitHeader fh = do
  emitComment fh "NOTE: THIS FILE IS GENERATED. DO NOT EDIT."
  time <- timestamp
  emitComment fh time
  where timestamp = do
          time <- getZonedTime
          return $ "Generated on " ++ (show time) ++ "."

emitLibrary :: Handle -> String -> IO ()
emitLibrary fh name = do
  emitEnum fh "GeneralCategory" (map show categories)
  emit ("class " ++ name ++ " { ")
  -- emitConstant
  iter emitFun functions
  emit "}"
  where
    emit s = hPutStrLn fh s
    iter :: (Handle -> a -> IO ()) -> [a] -> IO ()
    iter _ [] = return ()
    iter f (x : xs) = do
      _ <- f fh x
      iter f xs

emitGetCategory :: Handle -> IO ()
emitGetCategory fh = do
  emit "GeneralCategory category(int c) {"
  emit "  switch (c) {"
  emitCases (take 2 categoriesMapping)
  emit "  }"
  where
    emit s = hPutStrLn fh s
    emitCase :: Char -> IO ()
    emitCase c = emit ("  case " ++ hexCode c ++ ":")
    emitCases :: [(GeneralCategory, [Char])] -> IO ()
    emitCases [] = return ()
    emitCases ((cat, cases) : rest) = do
      mapM_ emitCase cases
      emit ("return GeneralCategory." ++ show cat)
      emitCases rest

main :: IO ()
main = do
  putStrLn "hello world"
