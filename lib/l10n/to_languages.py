import pandas as pd

main_file = "languages.dart"

def init_files(codes):
    with open(main_file, 'w') as f:
        head = "import 'package:flutter/material.dart';\n\nabstract class Languages {\nstatic Languages of(BuildContext context) {\nreturn Localizations.of<Languages>(context, Languages)!;\n\n}"
        f.write(head)
    for code in codes:
        title = "language_{}.dart".format(code)
        head = "import '{}';\n\nclass Language{} extends Languages {{\n".format(
            main_file, code.capitalize())
        with open(title, 'w') as f:
            f.write(head)


def close_files(codes):
    foot = "\n}\n"
    with open(main_file, 'a') as f:
        f.write(foot)
    for code in codes:
        title = "language_{}.dart".format(code)
        with open(title, 'a') as f:
            f.write(foot)


def add_to_languages(str):
    with open(main_file, 'a') as f:
        f.write(str)


def add_to_language_code(codes, str):
    for code in codes:
        title = "language_{}.dart".format(code)
        with open(title, 'a') as f:
            f.write(str)


def write_files(df, codes):
    for x in df.itertuples(index=False):
        if '#' in x.Code:
            str = "\n/// {} ///\n".format(x.Code.replace('#', ''))
            add_to_languages(str)
            add_to_language_code(codes, str)
        else:
            str = "String get {};\n".format(x.Code)
            add_to_languages(str)
            i = 1
            for code in codes:
                value = x[i] if pd.notna(x[i]) else x[1]
                str = "@override\nString get {} => \"{}\";\n".format(
                    x.Code, value.replace('$', '\$'))
                c = []
                c.append(code)
                add_to_language_code(c, str)
                i = i+1


file = "strings.xlsx"
df = pd.read_excel(file)
codes = []
for x in df:
    if (x != "Code"):
        codes.append(x)

init_files(codes)
write_files(df, codes)
close_files(codes)
