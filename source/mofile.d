/**
 * Parse .mo files and find translated messages.
 * Authors:
 *  $(LINK2 https://github.com/FreeSlave, Roman Chistokhodov)
 * Copyright:
 *  Roman Chistokhodov, 2018
 * License:
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * See_Also:
 *  $(LINK2 https://www.gnu.org/software/gettext/manual/html_node/MO-Files.html, The Format of GNU MO Files)
 */

module mofile;
///
class PluralFormException : Exception
{
    pure nothrow @nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null) {
        super(msg, file, line, nextInChain);
    }
}

///
class MoFileException : Exception
{
    pure nothrow @nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null) {
        super(msg, file, line, nextInChain);
    }
}

private @safe
{
    import std.conv : parse;
    import std.ascii;
    enum : ushort {
        SHL = ubyte.max + 1,
        SHR,
        AND,
        OR,
        LTE,
        GTE,
        EQ,
        NEQ,
        NUM,
    }

    class Plural
    {
    pure:
        abstract int opCall(int n = 0) const;
        abstract Plural clone();
    }

    class Unary : Plural
    {
    pure:
        this(Plural op) {
            op1 = op;
        }
    protected:
        Plural op1;
    }

    class Binary : Plural
    {
    pure:
        this(Plural first, Plural second) {
            op1 = first;
            op2 = second;
        }
    protected:
        Plural op1, op2;
    }

    final class Number : Plural
    {
    pure:
        this(int number) {
            num = number;
        }
        override Plural clone() {
            return new Number(num);
        }
        override int opCall(int) const {
            return num;
        }
    private:
        int num;
    }


    final class UnaryOp(string op) : Unary
    {
    pure:
        this(Plural op1) {
            super(op1);
        }
        override int opCall(int n) const {
            return mixin(op ~ " op1(n)");
        }
        override Plural clone() {
            return new UnaryOp!(op)(op1.clone());
        }
    }

    final class BinaryOp(string op) : Binary
    {
    pure:
        this(Plural first, Plural second) {
            super(first, second);
        }
        override int opCall(int n) const {
            return mixin("op1(n)" ~ op ~ "op2(n)");
        }
        override Plural clone() {
            return new BinaryOp!(op)(op1.clone(), op2.clone());
        }
    }

    final class BinaryOpD(string op) : Binary
    {
    pure:
        this(Plural first, Plural second) {
            super(first, second);
        }
        override int opCall(int n) const {
            int v2 = op2(n);
            if (v2 == 0) {
                throw new PluralFormException("Division by zero during plural form computation");
            }
            return mixin("op1(n)" ~ op ~ "v2");
        }
        override Plural clone() {
            return new BinaryOp!(op)(op1.clone(), op2.clone());
        }
    }

    alias UnaryOp!"!" Not;
    alias UnaryOp!"-" Minus;
    alias UnaryOp!"~" Invert;

    alias BinaryOp!"*" Mul;
    alias BinaryOpD!"/" Div;
    alias BinaryOpD!"%" Mod;

    alias BinaryOp!"+" Add;
    alias BinaryOp!"-" Sub;

    alias BinaryOp!"<<" Shl;
    alias BinaryOp!">>" Shr;

    alias BinaryOp!">" Gt;
    alias BinaryOp!"<" Lt;
    alias BinaryOp!">=" Gte;
    alias BinaryOp!"<=" Lte;

    alias BinaryOp!"==" Eq;
    alias BinaryOp!"!=" Neq;

    alias BinaryOp!"&" BinAnd;
    alias BinaryOp!"^" BinXor;
    alias BinaryOp!"|" BinOr;

    alias BinaryOp!"&&" And;
    alias BinaryOp!"||" Or;

    unittest
    {
        Plural op = new Mul(new Number(5), new Minus(new Number(10)));
        assert(op() == -50);
        op = new Eq(new Number(42), new Add(new Number(20), new Number(22)));
        assert(op() == 1);
        op = new Div(new Number(12), new Number(3));
        assert(op() == 4);
    }

    struct Tokenizer
    {
    pure:
        this(string contents) {
            content = contents;
            get();
        }

        @property ushort front() const pure nothrow @nogc {
            return current;
        }
        @property bool empty() const pure nothrow @nogc {
            return current == 0;
        }
        void popFront() {
            get();
        }
        int getNumber() {
            if (current == NUM)
                return number;
            else
                throw new PluralFormException("Not a number");
        }
    private:
        @trusted void get() {
            while(content.length > pos && isWhite(content[pos])) {
                pos++;
            }
            if (pos >= content.length) {
                current = 0;
                return;
            }
            if (content.length >= pos+2) {
                pos += 2;
                switch(content[pos-2..pos]) {
                    case "<<": current = SHL; return;
                    case ">>": current = SHR; return;
                    case "&&": current = AND; return;
                    case "||": current = OR; return;
                    case "<=": current = LTE; return;
                    case ">=": current = GTE; return;
                    case "==": current = EQ; return;
                    case "!=": current = NEQ; return;
                    default: pos -= 2; break;
                }
            }
            if (isDigit(content[pos])) {
                auto tmp = content[pos..$];
                number = parse!int(tmp);
                current = NUM;
                pos += tmp.ptr - (content.ptr + pos);
            } else {
                current = cast(ushort)content[pos];
                pos++;
            }
        }

        int number;
        ushort current;
        size_t pos;
        string content;
    }

    unittest
    {
        string contents = "n %10 ==1\n";
        auto tokenizer = Tokenizer(contents);
        assert(!tokenizer.empty);
        assert(tokenizer.front == 'n');
        tokenizer.popFront();
        assert(tokenizer.front == '%');
        tokenizer.popFront();
        assert(tokenizer.front == NUM);
        assert(tokenizer.getNumber == 10);
        tokenizer.popFront();
        assert(tokenizer.front == EQ);
        tokenizer.popFront();
        assert(tokenizer.front == NUM);
        assert(tokenizer.getNumber == 1);
        tokenizer.popFront();
        assert(tokenizer.empty);

        tokenizer = Tokenizer("");
        assert(tokenizer.empty);
    }

    final class Variable : Plural
    {
    pure:
        this() {
        }
        override int opCall(int n) const {
            return n;
        }
        override Plural clone() {
            return new Variable();
        }
    }

    final class Conditional : Plural
    {
    pure:
        this(Plural cond, Plural res, Plural alt) {
            this.cond = cond;
            this.res = res;
            this.alt = alt;
        }
        override int opCall(int n) const {
            return cond(n) ? res(n) : alt(n);
        }
        override Plural clone() {
            return new Conditional(cond, res, alt);
        }
    private:
        Plural cond, res, alt;
    }

    struct Parser
    {
    pure:
        this(Tokenizer tokenizer) {
            t = tokenizer;
        }

        this(string content) {
            this(Tokenizer(content));
        }

        Plural compile() {
            Plural expr = condExpr();
            if (expr && !t.empty) {
                throw new PluralFormException("Not in the end");
            }
            return expr;
        }

    private:
        Plural valueExpr() {
            if (t.front == '(') {
                t.popFront();
                Plural op = condExpr();
                if (op is null)
                    return null;
                if (t.front != ')')
                    throw new PluralFormException("Missing ')' in expression");
                t.popFront();
                return op;
            } else if (t.front == NUM) {
                int number = t.getNumber();
                t.popFront();
                return new Number(number);
            } else if (t.front == 'n') {
                t.popFront();
                return new Variable();
            } else {
                throw new PluralFormException("Unknown operand");
            }
            assert(false);
        }

        Plural unaryExpr() {
            Plural op1;
            ushort op = t.front;
            if (op == '-' || op == '~' || op == '!') {
                t.popFront();
                op1 = unaryExpr();
                if (op1) {
                    switch(op) {
                        case '-': return new Minus(op1);
                        case '~': return new Invert(op1);
                        case '!': return new Not(op1);
                        default: assert(false);
                    }
                } else {
                    return null;
                }
            } else {
                return valueExpr();
            }
        }

        static int getPrec(const ushort op) {
            switch(op) {
                case '/':
                case '*':
                case '%':
                    return 10;
                case '+':
                case '-':
                    return 9;
                case SHL:
                case SHR:
                    return 8;
                case '>':
                case '<':
                case GTE:
                case LTE:
                    return 7;
                case  EQ:
                case NEQ:
                    return 6;
                case '&':
                    return 5;
                case '^':
                    return 4;
                case '|':
                    return 3;
                case AND:
                    return 2;
                case  OR:
                    return 1;
                default:
                    return 0;
            }
        }

        static Plural binaryFactory(const ushort op, Plural left, Plural right) {
            switch(op) {
                case '/':  return new Div(left,right);
                case '*':  return new Mul(left,right);
                case '%':  return new Mod(left,right);
                case '+':  return new Add(left,right);
                case '-':  return new Sub(left,right);
                case SHL:  return new Shl(left,right);
                case SHR:  return new Shr(left,right);
                case '>':  return new  Gt(left,right);
                case '<':  return new  Lt(left,right);
                case GTE:  return new Gte(left,right);
                case LTE:  return new Lte(left,right);
                case  EQ:  return new  Eq(left,right);
                case NEQ:  return new Neq(left,right);
                case '&':  return new BinAnd(left,right);
                case '^':  return new BinXor(left,right);
                case '|':  return new BinOr(left,right);
                case AND:  return new And(left,right);
                case  OR:  return new Or(left,right);
                default:   return null;
            }
        }

        Plural binaryExpr(const int prec = 1) {
            assert(prec >= 1 && prec <= 11);
            Plural op1,op2;
            if (prec == 11)
                op1 = unaryExpr();
            else
                op1 = binaryExpr(prec+1);
            if (op1 is null)
                return null;
            if (prec != 11) {
                while(getPrec(t.front) == prec) {
                    ushort o = t.front;
                    t.popFront();
                    op2 = binaryExpr(prec+1);
                    if (op2 is null)
                        return null;
                    op1 = binaryFactory(o, op1, op2);
                }
            }

            return op1;
        }

        Plural condExpr() {
            Plural cond, case1, case2;
            cond = binaryExpr();
            if(cond is null)
                return null;
            if(t.front == '?') {
                t.popFront();
                case1 = condExpr();
                if(case1 is null)
                    return null;
                if(t.front != ':')
                    throw new PluralFormException("Missing ':' in conditional operator");
                t.popFront();
                case2 = condExpr();
                if(case2 is null)
                    return null;
            } else {
                return cond;
            }
            return new Conditional(cond,case1,case2);
        }

        Tokenizer t;
    }

    unittest
    {
        auto parser = new Parser("(n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2)");
        auto expr = parser.compile();
        assert(expr !is null);
        assert(expr(1) == 0);
        assert(expr(101) == 0);
        assert(expr(2) == 1);
        assert(expr(24) == 1);
        assert(expr(104) == 1);
        assert(expr(222) == 1);
        assert(expr(11) == 2);
        assert(expr(14) == 2);
        assert(expr(111) == 2);
        assert(expr(210) == 2);

        import std.exception : assertThrown;
        assertThrown(new Parser("").compile());
        assertThrown(new Parser("n?1").compile());
        assertThrown(new Parser("(2-1").compile());
        assertThrown(new Parser("p").compile());
        assertThrown(new Parser("1+2;").compile());
    }
}

import std.exception : assumeUnique, enforce;
import std.range : iota, assumeSorted, drop;
import std.algorithm.iteration : map, splitter;
import std.algorithm.searching : all, find, findSkip, skipOver;
import std.algorithm.sorting : isSorted;
import std.string : lineSplitter, stripRight;
import std.typecons : tuple;

/**
 * Struct representing .mo file.
 *
 * Default constructed object returns untranslated messages.
 */
@safe struct MoFile
{
    /**
     * Read from file.
     *
     * $(D mofile.MoFileException) if data is in invalid or unsupported format.
     * $(D mofile.PluralFormException) if plural form expression could not be parsed.
     * $(B FileException) on file reading error.
     */
    @trusted this(string fileName) {
        import std.file : read;
        this(read(fileName).assumeUnique);
    }

    /**
     * Constructor from data.
     * Data must be immutable and live as long as translated messages are used, because it's used to return strings.
     * Throws:
     * $(D mofile.MoFileException) if data is in invalid or unsupported format.
     * $(D mofile.PluralFormException) if plural form expression could not be parsed.
     */
    @safe this(immutable(void)[] data) pure {
        this.data = data;
        const magic = readValue!int(0);
        if (magic != 0x950412de) {
            throw new MoFileException("Wrong magic");
        }
        const revision = readValue!int(int.sizeof);
        if (revision != 0) {
            throw new MoFileException("Unknown revision");
        }

        baseOffsetOrig = readValue!int(int.sizeof*3);
        baseOffsetTr = readValue!int(int.sizeof*4);
        count = readValue!int(int.sizeof*2);

        if (count <= 0) {
            throw new MoFileException("Invalid count of msgids, must be at least 1");
        }

        auto mapped = iota(1,count).map!(i => getMessage(baseOffsetOrig, i));
        enforce!MoFileException(mapped.isSorted, "Invalid .mo file: message ids are not sorted");
        enforce!MoFileException(mapped.all!"!a.empty", "Some msgid besides the reserved one is empty");

        string header = getMessage(baseOffsetTr, 0);
        foreach(line; header.lineSplitter) {
            if (line.skipOver("Plural-Forms:")) {
                if (line.findSkip("plural=")) {
                    string expr = line.stripRight("\n\r;");
                    auto parser = new Parser(expr);
                    compiled = parser.compile();
                }
            }
        }
    }

    /**
     * .mo file header that includes some info like creation date, language and translator's name.
     */
    string header() pure const {
        if (count)
            return getMessage(baseOffsetTr, 0);
        return string.init;
    }

    /**
     * Get translated message.
     * Params:
     *  msgid = Message id (usually untranslated string)
     * Returns: Translated message for the msgid.
     *  If translation for this msgid does not exist or MoFile is default constructed the msgid is returned.
     */
    string gettext(string msgid) pure const {
        int index = getIndex(msgid);
        if (index >= 0) {
            string translated = getMessage(baseOffsetTr, index);
            auto splitted = translated.splitter('\0');
            if (!splitted.empty && splitted.front.length)
                return splitted.front;
        }
        return msgid;
    }

    /**
     * Get translated message considering plural forms.
     * Params:
     *  msgid = Untranslated message in singular form
     *  msgid_plural = Untranslated message in plural form.
     *  n = Number to calculate a plural form.
     * Returns: Translated string in plural form dependent on number n.
     *  If translation for this msgid does not exist or MoFile is default constructed then the msgid is returned if n == 1 and msgid_plural otherwise.
     */
    string ngettext(string msgid, string msgid_plural, int n) pure const {
        int index = getIndex(msgid);
        if (compiled !is null && index >= 0) {
            string translated = getMessage(baseOffsetTr, index);
            auto splitted = translated.splitter('\0');
            if (!splitted.empty && splitted.front.length) {
                int pluralForm = compiled(n);
                auto forms = splitted.drop(pluralForm);
                if (!forms.empty)
                    return forms.front;
            }
        }
        return n == 1 ? msgid : msgid_plural;
    }

private:
    @trusted int getIndex(string message) pure const {
        if (data.length == 0)
            return -1;
        if (message.length == 0)
            return 0;
        auto sorted = iota(1, count).map!(i => tuple(i, getMessage(baseOffsetOrig, i).splitter('\0').front)).assumeSorted!"a[1] < b[1]";
        auto found = sorted.equalRange(tuple(0, message));
        if (found.empty) {
            return -1;
        } else {
            return found.front[0];
        }
    }

    @trusted T readValue(T)(size_t offset) pure const
    {
        if (data.length >= offset + T.sizeof) {
            T value = *(cast(const(T)*)data[offset..(offset+T.sizeof)].ptr);
            return value;
        } else {
            throw new MoFileException("Value is out of bounds");
        }
    }

    @trusted string readString(int len, int offset) pure const
    {
        if (data.length >= offset + len) {
            string s = cast(string)data[offset..offset+len];
            return s;
        } else {
            throw new MoFileException("String is out of bounds");
        }
    }

    @trusted string getMessage(int offset, int i) pure const {
        return readString(readValue!int(offset + i*int.sizeof*2), readValue!int(offset + i*int.sizeof*2 + int.sizeof));
    }

    int count;
    int baseOffsetOrig;
    int baseOffsetTr;
    immutable(void[]) data;
    Plural compiled;
}

unittest
{
    MoFile moFile;
    assert(moFile.header.length == 0);
    assert(moFile.gettext("Hello") == "Hello");
    assert(moFile.ngettext("File", "Files", 1) == "File");
    assert(moFile.ngettext("File", "Files", 2) == "Files");
    assert(moFile.ngettext("File", "Files", 0) == "Files");
}
