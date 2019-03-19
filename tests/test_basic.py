import pytest
import trio

from trio_inspector import TrioInspector


@pytest.fixture
async def inspector():
    return TrioInspector()


async def test_startup(inspector):
    with trio.move_on_after(1):
        await inspector.run()
