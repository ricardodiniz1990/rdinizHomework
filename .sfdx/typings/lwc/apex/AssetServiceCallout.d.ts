declare module "@salesforce/apex/AssetServiceCallout.getAssetServiceInfo" {
  export default function getAssetServiceInfo(): Promise<any>;
}
declare module "@salesforce/apex/AssetServiceCallout.parseJSONString" {
  export default function parseJSONString(param: {jsonStr: any}): Promise<any>;
}
declare module "@salesforce/apex/AssetServiceCallout.assetMapping" {
  export default function assetMapping(param: {objectInfo: any}): Promise<any>;
}
declare module "@salesforce/apex/AssetServiceCallout.getDateValue" {
  export default function getDateValue(param: {dateString: any}): Promise<any>;
}
