# Mofile

D library for parsing .mo files and getting translated messages. Support for plural forms is present. Usage is similar to [GNU gettext](https://www.gnu.org/software/gettext/).

[![Build Status](https://github.com/FreeSlave/mofile/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/FreeSlave/mofile/actions/workflows/ci.yml) [![Coverage Status](https://coveralls.io/repos/FreeSlave/mofile/badge.svg?branch=master&service=github)](https://coveralls.io/github/FreeSlave/mofile?branch=master)

[Online documentation](https://freeslave.github.io/mofile/mofile.html)

## Usage

```d
import mofile;
// Parse .mo file
MoFile moFile = MoFile("ru.mo");
// Find translation
string s = moFile.gettext("Hello, world");
// Trying out plural forms
s = moFile.ngettext("File", "Files", 1);
s = moFile.ngettext("File", "Files", 3);
s = moFile.ngettext("File", "Files", 5);
```

## [Example](examples/gettext.d)

Commandline analogue of gettext and ngettext functions.

To run this example you must have some .mo file.
For a quick start there's already [template](examples/messages.pot) and [Russian translation](examples/ru.po) example files, so you only need to generate .mo file:

    msgfmt --no-hash examples/ru.po -o examples/ru.mo
    # The library currently does not support lookup by hash, so we omit hash generation.

And then run:

    dub examples/gettext.d examples/ru.mo "Hello, world"
    dub examples/gettext.d examples/ru.mo "File" "Files" 1
    dub examples/gettext.d examples/ru.mo "File" "Files" 3
    dub examples/gettext.d examples/ru.mo "File" "Files" 5
    dub examples/gettext.d examples/ru.mo "" # Get header

Generic use:

    dub examples/gettext.d $MOFILE msgid # msgid is a string to translate
    dub examples/gettext.d $MOFILE msgid msgid_plural n # msgid_plural is an untranslated plural form of message, n is a number to calculate a plural form from.

## How to generate .mo file from source file

Mostly the same way as in C/C++ projects.
Step by step process of generation .mo file from source file (gettext utilities must be installed):

    SOURCE=examples/main.d
    TEMPLATE=examples/messages.pot
    POFILE=examples/ru.po
    MOFILE=examples/ru.mo
    MSGLOCALE=ru_RU.UTF-8 # Target locale
    xgettext --from-code=UTF-8 --language=C "$SOURCE" -o "$TEMPLATE" # Create template file.
    msginit --locale=$MSGLOCALE -i "$TEMPLATE" -o "$POFILE" --no-translator # Generate text translation file
    # ... translate messages in editor
    msgfmt "$POFILE" -o "$MOFILE" # Generate binary translation file

If source file has been changed run these commands to update translation files:

    xgettext -j --from-code=UTF-8 --language=C "$SOURCE" -o "$TEMPLATE" # Update template file.
    msgmerge --update $POFILE "$TEMPLATE"
    # ... fix translations if needed
    msgfmt "$POFILE" -o "$MOFILE"
