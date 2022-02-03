trigger SimulationRequests on SimulationRequest__e (after insert) {
    try{
        List<SimulationResult__e> results = new List<SimulationResult__e>();

        Id memberId;
        List<SObject> records;
        SimulationResult__e result;
        // Iterate through each notification.
        for (SimulationRequest__e event : Trigger.New) {
            memberId = event.Member__c;
            records = (List<SObject>) JSON.deserialize(event.Records__c, List<SObject>.class);

            try {
                String simResults = JSON.serialize(FieloPLT.SimulationAPI.simulateRewarding(records, Id.valueOf(memberId), false));

                results.add(new SimulationResult__e(
                    Request__c = event.EventUuid,
                    Result__c = simResults
                ));
            } catch(Exception e) {
                ErrorService.insertError(e);
            }
        }

        if (results?.isempty() == false) {
            // Call method to publish events
            List<Database.SaveResult> eventResults = EventBus.publish(results);

            List<Database.Error> errors = new List<Database.Error>();

            // Inspect publishing result for each event
            for (Database.SaveResult eventResult : eventResults) {
                if (!eventResult.isSuccess()) {
                    errors.addAll(eventResult.getErrors());
                }
            }

            if (!errors.isEmpty()) {
                ErrorService.insertErrors(errors);
            }
        }
    } catch(DmlException e) {
        ErrorService.insertError(e);
    } catch(Exception e) {
        ErrorService.insertError(e);
    }
}