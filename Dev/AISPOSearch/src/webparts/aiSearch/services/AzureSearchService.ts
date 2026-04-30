export default class AzureSearchService {

  constructor(
    private endpoint: string,
    private apiKey: string,
    private indexName: string
  ) {}

  public async search(query: string): Promise<any[]> {
    const url = `${this.endpoint}/indexes/${this.indexName}/docs/search?api-version=2023-07-01-Preview`;

    const body = {
      search: query,
      top: 10
    };

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'api-key': this.apiKey
      },
      body: JSON.stringify(body)
    });

    const json = await response.json();
    return json.value || [];
  }
}
