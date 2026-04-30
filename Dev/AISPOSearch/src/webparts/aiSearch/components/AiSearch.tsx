import * as React from 'react';
import styles from './IAiSearch.module.scss';
import { IAiSearchProps } from './IAiSearchProps';
import { IAzureSearchState } from './IAzureSearchState';
import AzureSearchService from '../services/AzureSearchService';
import { escape } from '@microsoft/sp-lodash-subset';

export default class AzureSearch extends React.Component<IAiSearchProps, IAzureSearchState> {

  private searchService: AzureSearchService;

  constructor(props: IAiSearchProps) {
    super(props);

    this.state = {
      query: '',
      results: [],
      loading: false
    };

    this.searchService = new AzureSearchService(
      props.searchEndpoint,
      props.apiKey,
      props.indexName
    );
  }

  private onSearch = async () => {
    this.setState({ loading: true });

    const results = await this.searchService.search(this.state.query);

    this.setState({
      results,
      loading: false
    });
  };

  public render(): React.ReactElement<IAiSearchProps> {
    return (
      <div>
        <input
          type="text"
          placeholder="Search…"
          value={this.state.query}
          onChange={(e) => this.setState({ query: e.target.value })}
        />
        <button onClick={this.onSearch}>Search</button>

        {this.state.loading && <p>Searching…</p>}

        <ul>
          {this.state.results.map((item: any, index: number) => (
            <li key={index}>{item['@search.score']} - {item.title || JSON.stringify(item)}</li>
          ))}
        </ul>
      </div>
    );
  }
}



