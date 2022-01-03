# BASHŌ (芭蕉) - an exporter for Calibre

## Why?

I own multiple eBook reading devices, but only my Kobo Aura One is compatible to be managed directly with Calibre.

Usually, I transfer some books manually to these other devices.
But it becomes cumbersome at some point.
So I decided to build a small helper to export the files I'm intestered in.

It connect to your library via the `calibredb` CLI and uses some `xmllint` and `jq` magic to do its job.

## Beware!

This is not finished! It's more in a "proof-of-concept" state and lacks some integrity checks, update handling, etc.
It's slow, and I've only tested it for my setup.
But for a first version it does what it's supposed to do and might be a starting point for you.

## How?

`./basho.sh <library location> <metadata>`

## What's next?

There's a lot to be desired:

* Check if an export already exists.
  The filenames already contain the `id` so this shouldn't be too hard.
* Fileformat restriction. Right now all formats are exported.
* Better logging/output.
* Better error handling.

## Who?

[MATSUO Bashō](https://en.wikipedia.org/wiki/Matsuo_Bash%C5%8D)

## License?

MIT. See LICENSE.
