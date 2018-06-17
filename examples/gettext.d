/+dub.sdl:
name "gettext"
dependency "mofile" path="../"
+/
import std.stdio;
import std.conv : to;
import mofile;

int main(string[] args)
{
    if (args.length < 3) {
        stderr.writefln("Usage: %s <file.mo> <msgid> [msgid_plural] [number]", );
        return 1;
    }

    string fileName = args[1];
    string msgid = args[2];
    auto moFile = MoFile(fileName);
    if (args.length > 3) {
        if (args.length < 5) {
            stderr.writefln("Must provide a number");
            return 1;
        } else {
            string msgid_plural = args[3];
            const int n = args[4].to!int;
            writefln("%s %s", n, moFile.ngettext(msgid, msgid_plural, n));
        }
    } else {
        writeln(moFile.gettext(msgid));
    }
    return 0;
}
