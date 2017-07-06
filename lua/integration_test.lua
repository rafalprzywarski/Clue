local t = require("ut")
local ct = require("clue_ut")
require("clue.compiler")

local run = function(source) loadstring(clue.compiler.compile(source))() end

local output
local print = function(text) output[#output + 1] = text end
clue.load_ns("clue.core")
t.describe("integration", {
    ["before each"] = function()
        t.save_global("clue.namespaces")
        clue.ns("test")
        clue.Var.push_bindings(clue.hash_map(clue.symbol("clue.core", "*print*"), clue.fn(print)))
        output = {}
    end,
    ["binding"] = function()
        run(
            "(ns user)\n" ..
            "(def a 10)\n" ..
            "(def b 20)\n" ..

            "(binding [a 30]\n" ..
            "    (*print* a)\n" ..
            "    (*print* b)\n" ..
            "    (binding [a 40 b 50]\n" ..
            "        (*print* a)\n" ..
            "        (*print* b))\n" ..
            "    (*print* a)\n" ..
            "    (*print* b))\n" ..

            "(*print* a)\n" ..
            "(*print* b)\n")
        t.assert_equals(output, {30, 20, 40, 50, 30, 20, 10, 20})
    end,
    ["try/finally"] = function()
        pcall(run,
            "(ns user)\n" ..
            "(try\n" ..
            "    (try\n" ..
            "        (*print* \"step 1\")\n" ..
            "        (*print* \"step 2\")\n" ..
            "        (map)\n" ..
            "        (finally\n" ..
            "            (*print* \"finally\")))\n" ..
            "    (finally\n" ..
            "        (*print* \"outer\"))\n" ..
            ")\n"
        )
        t.assert_equals(output, {"step 1", "step 2", "finally", "outer"})
    end,
    ["macros"] = function()
        run(
            "(ns macros)\n" ..

            "(defmacro or\n" ..
            "    ([] nil)\n" ..
            "    ([x] x)\n" ..
            "    ([x & next]\n" ..
            "        `(let [or# ~x]\n" ..
            "            (if or# or# (or ~@next)))))\n" ..

            "(defn f [x] (do (*print* \".\") x))\n" ..

            "(*print* 5)\n" ..
            "(or (f nil) (f nil) (f nil) (f nil) (f \"x\"))\n" ..
            "(*print* 4)\n" ..
            "(or (f nil) (f nil) (f nil) (f \"x\") (f \"x\"))\n" ..
            "(*print* 3)\n" ..
            "(or (f nil) (f nil) (f \"x\") (f \"x\") (f \"x\"))\n" ..
            "(*print* 2)\n" ..
            "(or (f nil) (f \"x\") (f \"x\") (f \"x\") (f \"x\"))\n" ..
            "(*print* 1)\n" ..
            "(or (f \"x\") (f \"x\") (f \"x\") (f \"x\") (f \"x\"))"
        )
        t.assert_equals(output, {5, ".", ".", ".", ".", ".", 4, ".", ".", ".", ".", 3, ".", ".", ".", 2, ".", ".", 1, "."})
    end,
    ["protocols"] = function()
        run(
            "(ns protocol-test)\n" ..

            "(defprotocol P\n" ..
            "    (foo [x])\n" ..
            "    (bar-me [x y]))\n" ..

            "(deftype Foo [a b c]\n" ..
            "    P\n" ..
            "    (foo [x] a)\n" ..
            "    (bar-me [this y] (+ c y)))\n" ..

            "(deftype Bar [a b]\n" ..
            "    P\n" ..
            "    (foo [this] b)\n" ..
            "    (bar-me [this y] (+ a y)))\n" ..

            "(extend \"string\"\n" ..
            "    P\n" ..
            "    {:foo (fn [s] (str \"foo \" s \" works\"))\n" ..
            "     :bar-me (fn [s y] (str \"bar-me \" s \" - \" y))})\n" ..

            "(*print* (foo (Foo. 1 2 3)))\n" ..
            "(*print* (bar-me (Foo. 1 2 3) 42))\n" ..
            "(*print* (foo (Bar. 1 2)))\n" ..
            "(*print* (bar-me (Bar. 1 2) 42))\n" ..
            "(*print* (foo \"abc\"))\n" ..
            "(*print* (bar-me \"cd\" \"ef\"))\n"
        )
        t.assert_equals(output, {1, 45, 2, 43, "foo abc works", "bar-me cd - ef"})
    end
})
