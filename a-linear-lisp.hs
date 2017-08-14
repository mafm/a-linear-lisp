module Main where

import Data.Char -- isDigit digitToInt

-- general testing function taking
-- a name to print
-- a function to test: a -> b
-- a list of pairs of input and expected output: [(a,b)]
myTest :: Show a => Eq b => Show b => String -> (a->b) -> [(a,b)] -> IO()
myTest name func testcases = do
        putStrLn ""
        putStrLn ("Testing " ++ name)
        myTest_inner func testcases
        putStrLn ("Finished testing for " ++ name)
        putStrLn ""
    where
        myTest_inner :: Show a => Eq b => Show b => (a->b) -> [(a,b)] -> IO()
        myTest_inner func []     = return ()
        myTest_inner func ((a,b):xs) = do
                                   myTest_inner_single func a b
                                   myTest_inner func xs
        myTest_inner_single :: Show a => Eq b => Show b => (a->b) -> a -> b -> IO()
        myTest_inner_single func inp exp =
                            if exp == (func inp)
                                then return () -- putStrLn ("Success for input " ++ (show inp))
                                else putStrLn ("FAILURE for input " ++ (show inp) ++ " got: " ++ (show (func inp)))

-- a function to convert entire decimal strings to integer
stringToInt :: String -> Int
stringToInt "" = 0
stringToInt xs = stringToIntInner 0 xs
    where
        stringToIntInner :: Int -> String -> Int
        stringToIntInner acc ""     = acc
        stringToIntInner acc (x:xs) = stringToIntInner (acc*10 + x') xs
            where x' = digitToInt x


-- (fn (name arg1 arg2 ... argn)
--     body)
-- (let (name value)
--      body)
-- (if cond
--     then-body
--     else-body)
-- (== a b)
-- (< a b)
-- (> a b)
-- (concat str1 str2)
-- "..."
-- [0-9]+

data Token = TSymbol String
           | TLparen
           | TRparen
           | TString String
           | TNumber Int
    deriving (Show, Eq)

lexer :: String     -> [Token]
lexer    ""          = []
lexer    (' ' :rest) = lexer rest
lexer    ('\n':rest) = lexer rest
lexer    ('\t':rest) = lexer rest
lexer    ('\r':rest) = lexer rest
lexer    ('(' :rest) = TLparen : lexer rest
lexer    (')' :rest) = TRparen : lexer rest
lexer    ('"' :rest) = (TString contents) : lexer rrest
    where (contents, rrest) = consumeString rest
             where consumeString :: String -> (String, String)
                   consumeString str = consumeStringInner "" str
                        where consumeStringInner :: String -> String -> (String, String)
                              consumeStringInner left ('"':right) = (left, right)
                              consumeStringInner left ""          = (left, "")
                              consumeStringInner left (r:right)   = consumeStringInner (left ++ [r]) right
lexer    (n   :rest) | isDigit n = TNumber (stringToInt (n:first)) : (lexer second )
              where (first, second) = break (not . isDigit) rest
lexer    (c   :rest) = (TSymbol (c:contents)) : lexer rrest
    where (contents, rrest) = break breaksSymbol rest
            where breaksSymbol :: Char -> Bool
                  breaksSymbol ' ' = True
                  breaksSymbol '\n' = True
                  breaksSymbol '\r' = True
                  breaksSymbol '\t' = True
                  breaksSymbol ')' = True
                  breaksSymbol '"' = True
                  breaksSymbol '(' = True
                  breaksSymbol _ = False


lexer_test :: IO ()
lexer_test = myTest "lexer" lexer testcases
    where testcases = [
                        ("(", [TLparen]),
                        (")", [TRparen]),
                        ("(hello + 11 1)", [TLparen, (TSymbol "hello"), (TSymbol "+"), (TNumber 11), (TNumber 1), TRparen]),
                        ("a", [(TSymbol "a")]),
                        ("(if a b c)", [TLparen, (TSymbol "if"), (TSymbol "a"), (TSymbol "b"), (TSymbol "c"), TRparen]),
                        ("(\"Hello\")", [TLparen, (TString "Hello"), TRparen]),
                        ("(\"Hello world\")", [TLparen, (TString "Hello world"), TRparen]),
                        ("", [])
                      ]

data SExpr = SSymbol String
           | SString String
           | SNumber Int
           | SLet String SExpr SExpr
           | SIf SExpr SExpr SExpr
           | SFdecl String [String] SExpr
           | SFcall String [SExpr]
    deriving (Show, Eq)

data Program = Program [SExpr]
    deriving (Show, Eq)

-- (fn (name arg1 arg2 ... argn)
--     body)
-- (let (name value)
--      body)
-- (if cond
--     then-body
--     else-body)
-- (== a b)
-- (< a b)
-- (> a b)
-- (concat str1 str2)
-- "..."
-- [0-9]+

parseValue :: Token -> SExpr
parseValue (TString contents) = (SString contents)
parseValue (TSymbol contents) = (SSymbol contents)
parseValue (TNumber contents) = (SNumber contents)
parseValue invalid = error $ "parseValue called with non-value: " ++ show invalid

parseSExprList :: [Token] -> ([SExpr], [Token])
parseSExprList [] = ([], [])
parseSExprList tokens = parseSExprListInner [] tokens
    where parseSExprListInner ::[SExpr] -> [Token]         -> ([SExpr], [Token])
          parseSExprListInner   sexprs     []               = (sexprs, [])
          parseSExprListInner   sexprs     (TRparen : rest) = (sexprs, rest)
          parseSExprListInner   sexprs     something        = parseSExprListInner (sexprs ++ [ssexpr]) rsomething
            where (ssexpr, rsomething) = parseSExpr something

parseParams :: [Token] -> ([String], [Token])
parseParams [] = ([], [])
parseParams tokens = parseParamsInner [] tokens
    where parseParamsInner ::[String] -> [Token]         -> ([String], [Token])
          parseParamsInner   strings     []               = (strings, [])
          parseParamsInner   strings     (TRparen : rest) = (strings, rest)
          parseParamsInner   strings     ((TSymbol contents) : rest) = parseParamsInner (strings ++ [contents]) rest

parseSExpr :: [Token] -> (SExpr, [Token])
parseSExpr ((TSymbol contents) : rest) = ((SSymbol contents), rest)
parseSExpr ((TNumber contents) : rest) = ((SNumber contents), rest)
parseSExpr (TLparen : (TSymbol "let") : TLparen : (TSymbol name) : value : TRparen : rest) = ((SLet name vvalue body), rrest)
    where (body, (TRparen:rrest)) = parseSExpr rest
          vvalue = parseValue value
parseSExpr (TLparen : (TSymbol "fn")  : TLparen : (TSymbol name) : rest) = ((SFdecl name params body), rest2)
    where (params, rest1) = parseParams rest
          (body,   (TRparen:rest2)) = parseSExpr rest1
parseSExpr (TLparen : (TSymbol "if")  : rest) = ((SIf cond body_then body_else), rest3)
    where (cond,      rest1) = parseSExpr rest
          (body_then, rest2) = parseSExpr rest1
          (body_else, (TRparen:rest3)) = parseSExpr rest2
parseSExpr (TLparen : (TSymbol name)  : rest) = ((SFcall name args), rrest)
    where (args, rrest) = parseSExprList rest
parseSExpr (val : rest) = ((parseValue val), rest)

parse :: [Token] -> Program
parse [] = Program []
parse tokens = Program (parse_inner tokens)
    where parse_inner :: [Token] -> [SExpr]
          parse_inner    [] = []
          parse_inner    tokens       = sexpr : parse_inner rest
            where (sexpr, rest) = parseSExpr tokens

parse_test :: IO ()
parse_test = myTest "parse" parse testcases
    where testcases = [
                        ([TLparen, (TSymbol "+"), (TNumber 1), (TNumber 2), TRparen],
                         (Program [(SFcall "+" [(SNumber 1), (SNumber 2)])])),
                        ([(TString "hello world")],
                         (Program [(SString "hello world")])),
                        ((lexer "(if a b c)"),
                         (Program [(SIf (SSymbol "a") (SSymbol "b") (SSymbol "c"))])),
                        ((lexer "(let (a b) c)"),
                         (Program [(SLet "a" (SSymbol "b") (SSymbol "c"))])),
                        ((lexer "(fn (foo a b) (+ a b))"),
                         (Program [(SFdecl "foo" ["a", "b"] (SFcall "+" [(SSymbol "a"), (SSymbol "b")]))])),
                        ((lexer "(concat \"Hello world\")"),
                         (Program [(SFcall "concat" [(SString "Hello world")])])),
                        ([],
                         (Program []))
                      ]

data Binding = Binding String SExpr

data Scope = EmptyScope
           | Scope Binding Scope

insert :: Scope -> String -> SExpr -> Scope
insert scope str val = Scope (Binding str val) scope

fetch :: Scope -> String -> SExpr
fetch EmptyScope str = error $ "Failed to find string: " ++ str
fetch (Scope (Binding str1 val1) _) str | str == str1 = val1
fetch (Scope _ scope) str = fetch scope str

truthy :: [String] -> Bool
truthy ["SString \"\""] = False
truthy ["SNumber 0"] = False
truthy _  = True

-- create the new scope for an fcall
fcallScope :: Scope -> [String] -> [SExpr] -> Scope
fcallScope scope [] [] = scope
fcallScope scope (s:strings) (v:vals) = fcallScope (insert scope s v) strings vals

eval_in_scope :: Scope -> [SExpr] -> [String]
eval_in_scope    _ [] = []
eval_in_scope    scope ((SSymbol name):rest) = (show (fetch scope name)) : eval_in_scope scope rest
eval_in_scope    scope ((SLet name val body):rest) = (eval_in_scope let_scope [body]) ++ eval_in_scope scope rest
    where let_scope = insert scope name val
eval_in_scope    scope ((SFdecl name params body):rest) = eval_in_scope new_scope rest
    where new_scope = insert scope name val
            where val = (SFdecl name params body)
eval_in_scope    scope ((SIf cond body_then body_else):rest) = if (truthy (eval_in_scope scope [cond]))
                                                               then (eval_in_scope scope [body_then])
                                                               else (eval_in_scope scope [body_else])
eval_in_scope    scope ((SFcall name args):rest) =  (eval_in_scope new_scope [fbody]) ++ eval_in_scope scope rest
    where (SFdecl _ params fbody) = fetch scope name
          new_scope = fcallScope scope params args
eval_in_scope    scope (val:rest) = (show val) : eval_in_scope scope rest

eval :: Program -> [String]
eval    (Program prog) = eval_in_scope EmptyScope prog

eval_test :: IO ()
eval_test = myTest "eval" eval testcases
    where testcases = [
                        ((parse (lexer "(let (a 2) a)")), ["SNumber 2"]),
                        ((parse (lexer "(let (a c) a)")), ["SSymbol \"c\""]),
                        ((parse (lexer "(let (a \"Hello\") a)")), ["SString \"Hello\""]),
                        ((parse (lexer "(let (a 14) (let (b 15) a))")), ["SNumber 14"]),
                        ((parse (lexer "(if 1       \"pass\" \"fail\")")), ["SString \"pass\""]),
                        ((parse (lexer "(if \"\"    \"fail\" \"pass\")")), ["SString \"pass\""]),
                        ((parse (lexer "(if \"heh\" \"pass\" \"fail\")")), ["SString \"pass\""]),
                        ((parse (lexer "(fn (car a b) a)")), []),
                        ((parse (lexer "(fn (car a b) a)(car 1 2)")), ["SNumber 1"]),
                        ((parse (lexer "")), [])
                      ]

main :: IO ()
main = do
    putStrLn ""
    lexer_test
    putStrLn ""
    parse_test
    putStrLn ""
    eval_test
    putStrLn ""

