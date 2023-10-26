public with sharing class BillBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {
    
    public List<Id> receivesBillByEmail = new List<Id>();
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        //this is a method that will query for all accounts that are active and have a value
        //for Bill_By_Email__c (Account.Active__c = \'Yes\' AND Bill_By_Email != null)
        //using the Database.getQueryLocator(String) method. Return the result of this method.
        //Hint: be sure to escape the single quotes surrounding \'Yes\' in your dynamic query!
        //query for the following fields:
        //Id, Bill_By_Email__c
        String query = 'SELECT Id, Bill_By_Email__c FROM Account WHERE Active__c = \'Yes\' AND Bill_By_Email__c != null';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<Account> scope){
        //this is a method that will process the queried for records by preparing
        //a list of account Ids (this.receivesBillByEmail) to carry over to the finish method.
        //we will do this by iterating over scope and checking whether Bill_By_Email__c == TRUE.
        //This method will also call our BillAPI.getBills() method.
        
            // Initialize the list
            this.receivesBillByEmail = new List<Id>();
            // Iterate over the scope
            for(Account acc : scope){
                // Check if Bill_By_Email__c is true
                if(acc.Bill_By_Email__c == true){
                    // Add the Id to the list
                    this.receivesBillByEmail.add(acc.Id);
                }
            }
            // Call the getBills method from BillAPI
            BillAPI.getBills();
        }
 
    public void finish(Database.BatchableContext bc){
        //this is the final method of the class, that will be called after all processing in the
        //start and execute methods is complete. We will use this method to send an email to each
        //customer in the receivesBillByEmail list. First, we must query for the recently created bills for
        //each account with the following nested query:
        //[SELECT Id, (SELECT Id FROM Bills__r ORDER BY CreatedDate DESC) FROM Account WHERE Id IN :this.receivesBillByEmail]
        
        //Query for the recently created bills for each account
        List<Account> accounts = [SELECT Id,Email__c, (SELECT Id FROM Bills__r ORDER BY CreatedDate DESC) FROM Account WHERE Id IN :this.receivesBillByEmail];

        //Initialize the maps
        Map<Id,Id> billMap=new Map<Id,Id>();// Key is Account id and value is bill id
        Map<Id,String> emailMap = new Map<Id,String>();// key is  Account id and value is email
        //We will then iterate over the results of this query and associate the Id of the most recent bill (value) with the
        //corresponding Id of the account Id (key) in a Map<Id, Id> that we will call billMap, using the .put(Id, Id)
        //method of the Map class:
        //https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm
        //we will also create a Map<Id, String> called emailMap, where we'll hold the Account Id (key) and account email (value).

        //Iterate over the results
        for(Account acc:accounts){
            //check if there are any bills
            if(!acc.Bills__r.isEmpty()){
                //Associate the Id of the most recent bill to the correspomding Id of the Account
                billMap.put(acc.Id,acc.Bills__r[0].Id);
                //Associate the account Id with the Account Email
                emailMap.put(acc.Id,acc.Email__c);
            }
        }
        //Next, we are going to prepare to call our BillEmailer.sendEmails(Map<String, Blob> emailsWithBills) method
        //The String in the map, which we'll call sendMap,will be the Account.Email__c field result, and the Blob
        //will be the PDF attachment we are sending. We will achieve this by iterating over the keyset for
        //billMap, putting the email from the account in the key of the key-value pair, and use the following
        //to generate a PDF for each bill Id in the value of the key-value pair:
        //PageReference pageRef = new PageReference('/apex/BillVFP?id=' + [BILLID]);
        //Blob pdfBlob = pageRef.getContentAsPDF();
        //hint: you'll need to use the .get() method of the Map class a couple of times here.

        //Initialize sendMap
        Map<String,Blob> sendMap=new Map<String,Blob>();//Key is Account id and value is Pdf
        //Iterate over the keyset for billmap
        for(Id accountId:billMap.keySet()){
            //Generate a PDF for each billid
            Pagereference pageRef=new Pagereference('/apex/BillVFP?id='+billMap.get(accountId));
            Blob pdfBlob=pageRef.getContentAsPDF();
         //put the email from the account in the key of the key-value pair
            sendMap.put(emailMap.get(accountId),pdfBlob);  
        }
        //finally, we will call our BillEmailer.sendEmails(sendMap) method. 
        //Remember, this method is VOID,so there will be no return value;
            BillEmailer.sendEmails(sendMap);
    }
}