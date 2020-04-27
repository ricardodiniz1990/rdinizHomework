public class AssetServiceCallout { 
    
    /*
     * Method to call the endpoint with the needed header attributes
	*/    
    @AuraEnabled
    public static void getAssetServiceInfo(){
        HttpRequest req = new HttpRequest();
        String endpoint = Label.AssetAPIEndpoint;
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        
        string clientIdKey = Label.ClientIdKey;
        string clientSecretKey = Label.ClientSecretKey;
        string correlationIdKey = Label.CorrelationIdKey;
        
        string clientIdValue = Label.ClientIdValue;
        string clientSecretValue = Label.ClientSecretValue;
        string correlationIdValue = Label.CorrelationIdValue;
                
        req.setHeader(clientIdKey, clientIdValue);
        req.setHeader(clientSecretKey, clientSecretValue);
        req.setHeader(correlationIdKey, correlationIdValue);
        
        Http http = new Http();
        HTTPResponse res = http.send(req);
        
        parseJSONString(res.getBody());
        
    }
    
    /*
     * Method to parse the response JSON
	*/
    @AuraEnabled
    public static void parseJSONString(String jsonStr) {

        List<Map<String, Object>> objectsRetreived = new List<Map<String, Object>>();
        
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
    
    /*
     * Method to map into the Asset object and its related Measuting Point and Vehicle Text Data records
	*/
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
		
        //Take the JSON data already parsed into a map, and set the respective Asset fields
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
                
                // Create the related Measuring Point if there is none with the same CounterReading for this Asset record
                Boolean alreadyExists = false;
                for(Measuring_Point__c mPoint : existingMeasuringPoints){
                    if(mesPoint.Asset__c == mPoint.Asset__c && mesPoint.Counter_Reading__c == mPoint.Counter_Reading__c){
                        alreadyExists = true;
                    }
                }
                if(!alreadyExists){
                	newMeasuringPoints.add(mesPoint);    
                }
                
                //Build the related Vehicle Text Data from the info on the JSON
                Vehicle_Text_Data__c vTData = new Vehicle_Text_Data__c();
                
                if(!existingVehicleTextData.isEmpty()){
                    vTData = existingVehicleTextData.get(0);
                }
                
                Map<String, Object> vTextData = (Map<String, Object>)assObj.get('vehicleTextData');
                
                Map<String, Object> informationText = (Map<String, Object>)vTextData.get('informationText');
                vTData.Information_text__c = (String)informationText.get('textLine');
                
                List<Object> noteTexts = (List<Object>)vTextData.get('noteText');
                vTData.Note_Text__c = '';
                for(Object result : noteTexts){
                    Map<String,Object> noteText = (Map<String,Object>)result;
                    if(noteText.get('tagColumn') != null){
                        vTData.Note_Text__c += '\n' + noteText.get('tagColumn');
                    }
                    if(noteText.get('textLine') != null){
                        vTData.Note_Text__c += '\n' + noteText.get('textLine');
                    }
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
    
    /*
     * Method to parse a string from "yyyymmdd" format to Date instance 
	*/
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