// not for compilation, just input file for xgettext
void main()
{
    MoFile moFile;
    moFile.gettext("Hello, world");
    moFile.ngettext("File", "Files", 4);
}
