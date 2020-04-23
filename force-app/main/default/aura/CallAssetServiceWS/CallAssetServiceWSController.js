({
	myAction : function(component) {
		var action = component.get("c.getAssetServiceInfo");
        action.setCallback(this, function(response) {
            var title = '';
            var type = '';
            var message = '';
            var state = response.getState();
            if (state === "SUCCESS"){
                //alert('Success');
                title = 'Success!';
            	type = 'success';
            	message = 'Data updated from server!';
            }
            else{
                //alert('AAAAAAAA');
                title = 'Error!';
            	type = 'error';
            	message = 'Error in calling server side action';                
            }
            var toastEvent = $A.get("e.force:showToast");
            toastEvent.setParams({
                "title" : title,
                "type" : type,
                "message" : message
            });
            toastEvent.fire();
            $A.get("e.force:refreshView").fire();
        });
        $A.enqueueAction(action);
    }
})