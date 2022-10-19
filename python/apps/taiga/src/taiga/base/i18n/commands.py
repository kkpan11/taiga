# -*- coding: utf-8 -*-
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2021-present Kaleidos Ventures SL

import logging

import typer
from babel.messages import frontend as babel_cli
from taiga.base.i18n import FALLBACK_LOCALE, ROOT_DIR, TRANSLATION_DIRECTORY, i18n
from taiga.base.utils import pprint
from taiga.base.utils.commands import set_working_directory
from taiga.conf import settings

logger = logging.getLogger(__name__)


cli = typer.Typer(
    name="The Taiga i18n Manager",
    help="Manage Taiga translations.",
    add_completion=True,
)


@cli.command(help="List available languages")
def list_languages() -> None:
    table = pprint.Table(title="Available languages")
    table.add_column("Code", style="bold yellow")
    table.add_column("Name (EN)")
    table.add_column("Language")
    table.add_column("Territory")
    table.add_column("Extra", style="italic")

    for loc in i18n.locales:
        code = str(loc)
        name = loc.english_name
        language = loc.language_name
        territory = loc.territory_name
        extra: list[str] = []
        if code == str(FALLBACK_LOCALE):
            extra.append("fallback")
        if code == settings.LANG:
            extra.append("default")

        table.add_row(code, name, language, territory, ", ".join(extra))

    console = pprint.Console()
    console.print(table)


@cli.command(help="Add a new language to the catalog")
def add_language(lang_code: str) -> None:
    try:
        cmd = babel_cli.init_catalog()
        cmd.input_file = str(TRANSLATION_DIRECTORY.joinpath("messages.pot"))
        cmd.output_dir = str(TRANSLATION_DIRECTORY)
        cmd.locale = lang_code
        cmd.finalize_options()
        cmd.run()
        pprint.print(f"[green]Language '{lang_code}' added[/green]")
    except Exception:
        # DistutilsOptionError < babel.UnknownLocaleError
        pprint.print(f"[red]Language code '{lang_code}' does not exist[/red]")
        pprint.print(f"Valid Language code are: [green]{'[/green], [green]'.join(i18n.global_languages)}[/green]")


@cli.command(help="Update catalog (code to .po)")
def update_catalog() -> None:
    src_path = ROOT_DIR.parent  # src/

    with set_working_directory(src_path):
        extract_cmd = babel_cli.extract_messages()
        extract_cmd.mapping_file = str(src_path.joinpath("../babel.cfg"))
        extract_cmd.output_file = str(TRANSLATION_DIRECTORY.joinpath("messages.pot"))
        extract_cmd.input_paths = "./"
        extract_cmd.finalize_options()
        extract_cmd.run()

    cmd = babel_cli.update_catalog()
    cmd.input_file = str(TRANSLATION_DIRECTORY.joinpath("messages.pot"))
    cmd.output_dir = str(TRANSLATION_DIRECTORY)
    cmd.finalize_options()
    cmd.run()
    pprint.print("[green]Catalog updated[/green]")


@cli.command(help="Compile catalog (.po to .mo)")
def compile_catalog() -> None:
    cmd = babel_cli.compile_catalog()
    cmd.directory = str(TRANSLATION_DIRECTORY)
    cmd.finalize_options()
    cmd.run()  # type: ignore[no-untyped-call]
    pprint.print("[green]Catalog compiled[/green]")
