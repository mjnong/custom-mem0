import functools
from typing import Annotated

from mcp.server.fastmcp import Context, FastMCP
from mem0 import AsyncMemory
from mem0.configs.base import GraphStoreConfig, MemoryConfig
from mem0.configs.vector_stores.pgvector import PGVectorConfig
from mem0.embeddings.configs import EmbedderConfig
from mem0.graphs.configs import LlmConfig, Neo4jConfig
from mem0.vector_stores.configs import VectorStoreConfig
from pydantic import Field

from src.config.config import get_config


class MemoryMCP:
    _mcp = FastMCP("Memory", "Memory service for managing user and agent memories.")

    def __init__(self):
        """Initialize the Memory service with the appropriate configuration based on the backend specified in the config."""
        match get_config().backend:
            case "pgvector":
                self._config = MemoryConfig(
                    vector_store=VectorStoreConfig(
                        provider="pgvector",  # Use pgvector for Neo4j
                        config=PGVectorConfig(
                            host=get_config().postgres_host,
                            port=get_config().postgres_port,
                            dbname=get_config().postgres_database,
                            user=get_config().postgres_user,
                            password=get_config().postgres_password,
                            collection_name=get_config().postgres_collection_name,
                            diskann=True,  # Use DiskANN for efficient vector search
                            hnsw=False,  # Disable HNSW for Neo4j
                            embedding_model_dims=1536,  # Default dimensions for OpenAI embeddings
                        ).model_dump(),
                    )
                )
            case "qdrant":
                self._config = MemoryConfig(
                    vector_store=VectorStoreConfig(
                        provider="qdrant",
                        config={
                            "host": get_config().qdrant_host,
                            "port": get_config().qdrant_port
                        },
                    )
                )
            case _:
                raise ValueError(f"Unsupported backend: {get_config().backend}")
        # Initialize the graph store configuration
        self._config.graph_store = GraphStoreConfig(
            provider="neo4j",
            config=Neo4jConfig(
                url=f"bolt://{get_config().neo4j_ip}",  # URI format for Neo4j, when SSL/TLS is not used else it should be "neo4j+s://"
                username=get_config().neo4j_username,
                password=get_config().neo4j_password,
                database=None,
                base_label=None,
            ),
        )
        self._config.llm = LlmConfig(
            provider="openai",
            config={
                "api_key": get_config().openai_api_key,
                "model": get_config().openai_model,
            },
        )
        self._config.embedder = EmbedderConfig(
            provider="openai",
            config={
                "api_key": get_config().openai_api_key,
                "model": get_config().openai_embedding_model,
            },
        )
        self._config.history_db_path = get_config().history_db_path

        self._memory = AsyncMemory(config=self._config)

        # Register MCP tools and resources after initialization
        self._register_mcp_handlers()

    def _register_mcp_handlers(self):
        """Register MCP tools and resources after initialization."""

        # Create closure functions that have access to self._memory
        @self._mcp.tool(
            name="add_memory",
            title="Add Memory",
            description="Add a memory to the memory store.",
        )
        async def add_memory(
            data: Annotated[str, Field(description="The content of the memory.")],
            user_id: Annotated[
                str, Field(description="The ID of the user adding the memory.")
            ],
            agent_id: Annotated[
                str | None,
                Field(
                    description="Optional ID of the agent associated with the memory."
                ),
            ] = None,
        ):
            """
            Add a memory to the memory store.

            :param data: The content of the memory.
            :param user_id: The ID of the user adding the memory.
            :param agent_id: Optional ID of the agent associated with the memory.
            """
            await self._memory.add(data, user_id=user_id, agent_id=agent_id)

        @self._mcp.resource(
            "memories://{user_id}/{agent_id}/{limit}",
            title="Get All Memories",
            description="Retrieve all memories for a user or agent.",
            name="get_all_memories",
        )
        async def get_all_memories(
            user_id: Annotated[
                str,
                Field(
                    description="The ID of the user whose memories are to be retrieved."
                ),
            ],
            agent_id: Annotated[
                str | None,
                Field(
                    description="Optional ID of the agent associated with the memories."
                ),
            ] = None,
            limit: Annotated[
                int, Field(description="The maximum number of memories to retrieve.")
            ] = 100,
        ) -> dict:
            """
            Retrieve all memories for a user or agent.

            :param user_id: The ID of the user whose memories are to be retrieved.
            :param agent_id: Optional ID of the agent associated with the memories.
            :return: List of memories.
            """
            return await self._memory.get_all(
                user_id=user_id, agent_id=agent_id, limit=limit
            )

        @self._mcp.tool(
            name="delete_all_memories",
            title="Delete All Memories",
            description="Delete all memories for a user or agent.",
        )
        async def delete_all_memories(
            user_id: Annotated[
                str,
                Field(
                    description="The ID of the user whose memories are to be deleted."
                ),
            ],
            agent_id: Annotated[
                str | None,
                Field(
                    description="Optional ID of the agent associated with the memories."
                ),
            ] = None,
        ):
            """
            Delete all memories for a user or agent.

            :param user_id: The ID of the user whose memories are to be deleted.
            :param agent_id: Optional ID of the agent associated with the memories.
            """
            await self._memory.delete_all(user_id=user_id, agent_id=agent_id)

        @self._mcp.tool(
            name="search_memories",
            title="Search Memories",
            description="Search for memories matching a query.",
        )
        async def search_memories(
            query: Annotated[str, Field(description="The search query.")],
            user_id: Annotated[
                str, Field(description="The ID of the user performing the search.")
            ],
            ctx: Context,
            agent_id: Annotated[
                str | None,
                Field(
                    description="Optional ID of the agent associated with the search."
                ),
            ] = None,
        ) -> dict:
            """
            Search for memories matching the query.

            :param query: The search query.
            :param user_id: The ID of the user performing the search.
            :param agent_id: Optional ID of the agent associated with the search.
            :return: List of matching memories.
            """
            await ctx.info(
                f"Searching memories for user {user_id} with agent {agent_id}"
            )
            return await self._memory.search(query, user_id=user_id, agent_id=agent_id)

        @self._mcp.tool(
            name="update_memory",
            title="Update Memory",
            description="Update a specific memory by its ID.",
        )
        async def update_memory(
            memory_id: Annotated[
                str, Field(description="The ID of the memory to update.")
            ],
            data: Annotated[str, Field(description="The new content for the memory.")],
            ctx: Context,
        ) -> dict:
            """
            Update a specific memory by its ID.

            :param memory_id: The ID of the memory to update.
            :param data: The new content for the memory.
            """
            await ctx.info(f"Updating memory with ID {memory_id}")
            return await self._memory.update(memory_id, data)

        @self._mcp.tool(
            name="delete_memory",
            title="Delete Memory",
            description="Delete a specific memory by its ID.",
        )
        async def delete_memory(
            memory_id: Annotated[
                str, Field(description="The ID of the memory to delete.")
            ],
        ):
            """
            Delete a specific memory by its ID.

            :param memory_id: The ID of the memory to delete.
            """
            await self._memory.delete(memory_id)

    @property
    def mcp(self):
        """
        Get the FastMCP instance for the Memory service.

        :return: FastMCP instance.
        """
        return self._mcp


@functools.lru_cache(maxsize=1)
def get_memory_service() -> MemoryMCP:
    """
    Get a singleton instance of the Memory service.

    :return: Memory service instance.
    """
    return MemoryMCP()
