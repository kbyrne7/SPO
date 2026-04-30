import * as React from 'react';
import * as ReactDom from 'react-dom';
import { Version } from '@microsoft/sp-core-library';
import {
  IPropertyPaneConfiguration,
  PropertyPaneTextField
} from '@microsoft/sp-property-pane';
import { BaseClientSideWebPart } from '@microsoft/sp-webpart-base';
import * as strings from 'AiSearchWebPartStrings';
import AiSearch from './components/AiSearch';
import { IAiSearchProps } from './components/IAiSearchProps';

export interface IAiSearchWebPartProps {
  description: string;
  searchEndpoint: string;
  apiKey: string;
  indexName: string;
}

export default class AiSearchWebPart extends BaseClientSideWebPart<IAiSearchWebPartProps> {

  public render(): void {
    const element: React.ReactElement<IAiSearchProps> = React.createElement(
      AiSearch,
      {
        description: this.properties.description,
        searchEndpoint: this.properties.searchEndpoint,
        apiKey: this.properties.apiKey,
        indexName: this.properties.indexName
      }
    );

    ReactDom.render(element, this.domElement);
  }

  protected onDispose(): void {
    ReactDom.unmountComponentAtNode(this.domElement);
  }

  protected getPropertyPaneConfiguration(): IPropertyPaneConfiguration {
    return {
      pages: [
        {
          header: {
            description: strings.PropertyPaneDescription
          },
          groups: [
            {
              groupName: strings.BasicGroupName,
              groupFields: [
                PropertyPaneTextField('description', {
                  label: strings.DescriptionFieldLabel
                }),
                PropertyPaneTextField('searchEndpoint', {
                  label: "SearchEndpoint"
                }),
                PropertyPaneTextField('description', {
                  label: "apiKey"
                }),
                PropertyPaneTextField('description', {
                  label: "indexName"
                })
              ]
            }
          ]
        }
      ]
    };
  }
}
