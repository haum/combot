# coding: utf-8
#
# agenda_remove_old.py
#
# Copyright (C) 2015 Romain Porte (MicroJoe) <microjoe@mailoo.org>
#
#
# Distributed under WTFPL terms
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
# Copyright (C) 2004 Sam Hocevar <sam@hocevar.net>
#
# Everyone is permitted to copy and distribute verbatim or modified
# copies of this license document, and changing it is allowed as long
# as the name is changed.
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.
#

import datetime
import sqlite3

DB_FILEPATH = "/home/haum/agenda.sqlite"


# Connexion
print("Connexion à la base de données ({})...".format(DB_FILEPATH))
conn = sqlite3.connect(DB_FILEPATH)
print("Connexion établie.")

c = conn.cursor()

# Date actuelle
now = datetime.datetime.now()
print("Nous sommes le {}.".format(now.strftime("%d/%m/%Y")))

# On regarde la liste des éléments à supprimer
to_delete = []
for row in c.execute("select rowid,* from agenda where status=1"):
    rowid = row[0]

    # Parse la date au format JJ/MM/AAAA
    date = datetime.datetime.strptime(row[4], "%d/%m/%Y")

    # Ajoute à la liste d'éléments à supprimer si la date est passée
    if date < now:
        to_delete.append((rowid, row[1], row[4]))

# On les supprime
for rowid, name, date in to_delete:
    print("Suppression de l'évenement \"{}\" du {} (id={})".format(
        name, date, rowid))
    c.execute("update agenda set status=0 where rowid=?", (rowid,))

# On commit pour enregistrer
print("Commit...")
conn.commit()

# On ferme proprement la base
print("Fermeture de la base de données.")
conn.close()
