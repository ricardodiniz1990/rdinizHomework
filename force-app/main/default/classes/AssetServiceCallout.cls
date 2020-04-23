public class AssetServiceCallout {   
    
    @AuraEnabled
    public static void getAssetServiceInfo(){
        HttpRequest req = new HttpRequest();
        String endpoint = Label.AssetAPIEndpoint;
        //req.setEndpoint('https://eu1.anypoint.mulesoft.com/mocking/api/v1/sources/exchange/assets/a9111cc7-7a75-420b-996d-c403e449fb82/man-join-data-hub/1.0.2/m/JOINTHEDIGITALHUB');
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        
        //string clientIdKey = 'client-id';
        string clientIdKey = Label.ClientIdKey;
        //string clientSecretKey = 'client-secret';
        string clientSecretKey = Label.ClientSecretKey;
        //string correlationIdKey = 'correlation-id';
        string correlationIdKey = Label.CorrelationIdKey;
        
        string clientIdValue = Label.ClientIdValue;
        //string clientIdValue = 'b903e91e6c6542a3a4a6e800f37f95ea';
        string clientSecretValue = Label.ClientSecretValue;
        //string clientSecretValue = '4d73e495F84E4c47B8a8E37C8F8B96b3';
        string correlationIdValue = Label.CorrelationIdValue;
        //string correlationIdValue = 'a9111cc7-7a75-420b-996d-c403e449fb82';
                
        req.setHeader(clientIdKey, clientIdValue);
        req.setHeader(clientSecretKey, clientSecretValue);
        req.setHeader(correlationIdKey, correlationIdValue);
        
        Http http = new Http();
        HTTPResponse res = http.send(req);
        System.debug(res.getBody());
        
        parseJSONString(res.getBody());
        
    }
    
    @AuraEnabled
    public static void parseJSONString(String jsonStr) {

        List<Map<String, Object>> objectsRetreived = new List<Map<String, Object>>();
        
        //jsonStr = '{"assetInfoList":['+jsonStr+','+jsonStr+']}';
        jsonStr = '{"assetInfoList":['+jsonStr+']}';

        system.debug('jsonStr: ' + jsonStr);
        
        JSONParser parser = JSON.createParser(jsonStr);

        while (parser.nextToken() != null) {
            if (parser.getCurrentToken() == JSONToken.START_ARRAY) {
                while (parser.nextToken() != null) {
                    if (parser.getCurrentToken() == JSONToken.START_OBJECT) {
                        // read entire assetInfo object
                        AssetInfo assetInfo = (AssetInfo)parser.readValueAs(AssetInfo.class);
                        // serialize again to verify what was parsed.
                        String s = JSON.serialize(assetInfo);
                        system.debug('Serialized ASSET INFO: ' + s);

                        system.debug('DESEREALIZE TEST: ' + (AssetInfo) System.JSON.deserialize(s, AssetInfo.class));

                        Map<String, Object> m = (Map<String, Object>)JSON.deserializeUntyped(s);
                        
                       	objectsRetreived.add(m);
                        
                        // Skip the child start array and start object markers.
                        parser.skipChildren();
                    }
                }        
            }
        }
        assetMapping(objectsRetreived);
    }

    @AuraEnabled
    public static void assetMapping(List<Map<String, Object>> objectInfo){
        List<String> vinsToReturn = new List<String>();
        
        for(Map<String, Object> obj : objectInfo){
            vinsToReturn.add((String)obj.get('vin'));
        }
        
        List<Asset> getTheAsset = [SELECT Id, Name, VIN__c FROM Asset WHERE VIN__c IN :vinsToReturn];
        List<Asset> newAssets = new List<Asset>();
        List<Measuring_Point__c> newMeasuringPoints = new List<Measuring_Point__c>();
        List<Vehicle_Text_Data__c> upsertVehicleTextData = new List<Vehicle_Text_Data__c>();
        
        List<Vehicle_Text_Data__c> existingVehicleTextData = [SELECT Id, Information_Text__c, Note_Text__c, Asset__c FROM Vehicle_Text_Data__c WHERE Asset__c IN :getTheAsset];
        List<Measuring_Point__c> existingMeasuringPoints = [SELECT Id, Asset__c, Counter_Reading__c FROM Measuring_Point__c WHERE Asset__c IN :getTheAsset];

        for(Map<String, Object> assObj : objectInfo){
            String theVin = (String)assObj.get('vin');
            for(Asset ast : getTheAsset){
                System.debug('ASSET INFO: ' + ast.Name);
                if(ast.VIN__c == theVin){
                    ast.Vehicle_Number__c = (String)assObj.get('vehicleNum');
                    ast.Vehicle_Registration_Number__c = (String)assObj.get('vehicleRegNum');
                    ast.Registration_Number_Country_Key__c = (String)assObj.get('regNumCountryKey');
                    ast.OEM_VIN__c = (String)assObj.get('oemVin');
                    ast.Manufacturer__c = (String)assObj.get('manufacturer');
                    ast.Product_Code__c = (String)assObj.get('prodCode');
                    ast.Model_Range__c = (String)assObj.get('modelRange');
                    ast.Vehicle_Type__c = (Double)assObj.get('vehicleType');
                    ast.Type_Variant__c = (String)assObj.get('typeVariant');
                    ast.Delivery_Ex_Work_Date__c = getDateValue((String)assObj.get('deliveryExWorkDate'));
                    ast.First_Registration_Date__c = getDateValue((String)assObj.get('firstRegDate'));
                    ast.Wheel_Base__c = (Integer)assObj.get('wheelBase');
                    ast.Overhang__c = (Integer)assObj.get('overhang');
                    ast.Suspension__c = (String)assObj.get('suspension');
                    ast.Truck_Axle__c = (Integer)assObj.get('truckAxle');
                    ast.CustomerRegistration_Date__c = getDateValue((String)assObj.get('customerRegDate'));
                    ast.Customer_Number__c = (String)assObj.get('customerNo');
                    ast.Customer_Name__c = (String)assObj.get('customerName');
                }
                newAssets.add(ast);
                
                Measuring_Point__c mesPoint = new Measuring_Point__c();
                Map<String, Object> mPointData = (Map<String, Object>)assObj.get('measuringPoint');
                mesPoint.Counter_Reading__c = (Integer)mPointData.get('counterReading');
                mesPoint.Measure_Point__c = (String)mPointData.get('measPoint');
                mesPoint.Measure_Point_Unit__c = (String)mPointData.get('mpUnit');
                mesPoint.Asset__c = ast.Id;
                
                Boolean alreadyExists = false;
                for(Measuring_Point__c mPoint : existingMeasuringPoints){
                    if(mesPoint.Asset__c == mPoint.Asset__c && mesPoint.Counter_Reading__c == mPoint.Counter_Reading__c){
                        alreadyExists = true;
                    }
                }
                if(!alreadyExists){
                	newMeasuringPoints.add(mesPoint);    
                }
                
                Vehicle_Text_Data__c vTData = new Vehicle_Text_Data__c();
                
                if(!existingVehicleTextData.isEmpty()){
                    vTData = existingVehicleTextData.get(0);
                }
                
                Map<String, Object> vTextData = (Map<String, Object>)assObj.get('vehicleTextData');
                System.debug(':: RD :: vTextData: ' + vTextData);
                System.debug(':: RD :: vTextData: ' + vTextData.get('informationText'));
                System.debug(':: RD :: vTextData: ' + vTextData.get('noteText'));
                
                Map<String, Object> informationText = (Map<String, Object>)vTextData.get('informationText');
                System.debug(':: RD :: informationText: ' + informationText);
                vTData.Information_text__c = (String)informationText.get('textLine');
                System.debug(':: RD :: informationText: ' + informationText.get('textLine'));
                
                List<Object> noteTexts = (List<Object>)vTextData.get('noteText');
                vTData.Note_Text__c = '';
                for(Object result : noteTexts){
                    System.debug(':: RD :: noteText: ' + (Map<String,Object>)result);
                    Map<String,Object> noteText = (Map<String,Object>)result;
                    if(noteText.get('tagColumn') != null){
                        vTData.Note_Text__c += '\n' + noteText.get('tagColumn');
                    }
                    System.debug(':: RD :: noteText: ' + noteText.get('tagColumn'));
                    if(noteText.get('textLine') != null){
                        vTData.Note_Text__c += '\n' + noteText.get('textLine');
                    }
                    System.debug(':: RD :: noteText: ' + noteText.get('textLine'));
                }
                
                if(vTData.Asset__c == null){
                    vTData.Asset__c = ast.Id;
                }
                upsertVehicleTextData.add(vTData);
            }
        }        
        update newAssets;
        upsert newMeasuringPoints;
        upsert upsertVehicleTextData;
    }
    
    @AuraEnabled
    public static Date getDateValue(String dateString){
        String year1 = dateString.left(4);
        String month1 = dateString.substring(4, 6);
        String day1 = dateString.right(2);                    
        return Date.newInstance(Integer.valueOf(year1),Integer.valueOf(month1),Integer.valueOf(day1));
    }
    
    // Inner classes used for serialization by readValuesAs(). 
    
    public class AssetInfo {
        public string vin;
        public string vehicleNum;
        public string vehicleRegNum;
        public string regNumCountryKey;
        public string oemVin;
        public string manufacturer;
        public string prodCode;
        public string modelRange;
        public double vehicleType;
        public string typeVariant;
        public string deliveryExWorkDate;
        public string firstRegDate;
        public integer wheelBase;
        public integer overhang;
        public string suspension;
        public integer truckAxle;
        public string customerRegDate;
        public string customerNo;
        public string customerName;
        MeasuringPoint measuringPoint;
        VehicleTextData vehicleTextData;
        
        public AssetInfo(string vin, string vehicleNum, string vehicleRegNum, string regNumCountryKey, string oemVin,
                            string manufacturer, string prodCode, string modelRange, double vehicleType, string typeVariant,
                            string deliveryExWorkDate, string firstRegDate, integer wheelBase, integer overhang, string suspension, 
                            integer truckAxle, string customerRegDate, string customerNo, string customerName, string measPoint, long counterReading,
                            string mpUnit, VehicleTextData vehicleTextData) {
                             this.vin = vin;
                             this.vehicleNum = vehicleNum;
                             this.vehicleRegNum = vehicleRegNum;
                             this.regNumCountryKey = regNumCountryKey;
                             this.oemVin = oemVin;
                             this.manufacturer = manufacturer;
                             this.prodCode = prodCode;
                             this.modelRange = modelRange;
                             this.vehicleType = vehicleType;
                             this.typeVariant = typeVariant;
                             this.deliveryExWorkDate = deliveryExWorkDate;
                             this.firstRegDate = firstRegDate;
                             this.wheelBase = wheelBase;
                             this.overhang = overhang;
                             this.suspension = suspension;
                             this.truckAxle = truckAxle;
                             this.customerRegDate = customerRegDate;
                             this.customerNo = customerNo;
                             this.customerName = customerName;
                             this.measuringPoint = new MeasuringPoint(measPoint, counterReading, mpUnit);
                             this.vehicleTextData = new VehicleTextData(new InformationText(), new List<NoteText>());
                         }
    }  
    
    public class MeasuringPoint {
        public string measPoint;
        public long counterReading;
        public string mpUnit;

        public MeasuringPoint(string measPoint, long counterReading, string mpUnit){
            this.measPoint = measPoint;
            this.counterReading = counterReading;
            this.mpUnit = mpUnit;
        }

    }
    
    public class VehicleTextData {
        InformationText informationText;
        List<NoteText> noteText;

        public VehicleTextData(InformationText informationText, List<NoteText> noteText){
            this.informationText = informationText;
            this.noteText = noteText.clone();            
        }
    }
    
    public class InformationText {
        public string textLine;
    }

    public class NoteText {
        public string tagColumn;
        public string textLine;
    }
    
}