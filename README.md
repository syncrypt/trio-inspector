# Trio Inspector

Note: This is a very early prototype.

## Installation

```
pip install git+https://github.com/syncrypt/trio-inspector.git
```

## Usage

```
from trio_inspector import TrioInspector

...

async with trio.open_nursery() as nursery:
    nursery.start_soon(TrioInspector().run)
```

Then, point your browser to: http://127.0.0.1:5000/
