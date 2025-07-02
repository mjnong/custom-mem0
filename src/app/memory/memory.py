import asyncio
from mem0 import AsyncMemory
from mem0.configs.base import MemoryConfig

class Memory:
    def __init__(self):
        self._config = MemoryConfig(
            
        )
        self._memory = AsyncMemory()