SPO Audit and AI Search implementation in Azure with interface to SPO Online for advanced search capabilities

# Azure AI Search – SharePoint Indexer Configuration

This folder contains the full configuration for the SharePoint → Azure AI Search pipeline.

## Files
- datasource.json – SharePoint connection
- index.json – Current working index
- index.vector-ready.json – Future version with vector placeholders
- indexer.json – Indexer definition

## Restore
Run:
    ./scripts/recreate-search.ps1

## Future Upgrade (Vector Search)
When upgrading to a tier that supports vector search:
1. Open index.vector-ready.json
2. Uncomment:
   - contentVector field
   - vectorSearch block
3. Add a vectorizer (Azure OpenAI)
4. Recreate the index
5. Re-run the indexer

