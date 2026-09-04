public with sharing class FileUploadController {

    @AuraEnabled
    public static Map<String, String> saveFile(String  base64Data, String  fileName, String  recId, Integer durationSeconds) {
        Map<String, String> result = new Map<String, String>();
        try {
            Blob fileBlob = EncodingUtil.base64Decode(base64Data);
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName + '.mp3';
            cv.VersionData = fileBlob;

            if (String.isNotBlank(recId)) {
                cv.FirstPublishLocationId = recId;
            }

            insert cv;
            result.put('contentVersionId', cv.Id);
            
            Integer duration = durationSeconds != null ? durationSeconds : 0;
            Integer mins = duration / 60;
            Integer secs = Math.mod(duration, 60);
            String durationFormatted = mins + ':' + String.valueOf(secs).leftPad(2, '0');

            Audio_Recording__c rec = new Audio_Recording__c();
            rec.Recording_Name__c = fileName;
            rec.File_Name__c = fileName + '.mp3';
            rec.Duration_Minutes__c = durationFormatted;
            rec.Content_Version_Id__c = cv.Id;
            rec.Recorded_At__c = Datetime.now();
            rec.Status__c = 'Saved';

            if (String.isNotBlank(recId)) {
                Id sfRecId = Id.valueOf(recId);
                String objType = sfRecId.getSObjectType().getDescribe().getName();
                if(objType == 'Contact') {
                    rec.Related_Contact__c = sfRecId;
                }
                else if (objType == 'Opportunity') {
                    rec.Related_Opportunity__c = sfRecId;
                }
                else if (objType == 'Account') {
                    rec.Related_Account__c = sfRecId;
                }
            }

            insert rec;
            result.put('audioRecordingId', rec.Id);

            ContentVersion contentVersionObj = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = contentVersionObj.ContentDocumentId;
            cdl.LinkedEntityId = rec.Id;
            cdl.ShareType = 'V';
            cdl.Visibility = 'AllUsers';
            insert cdl;
            result.put('status', 'success');

        } catch (Exception e) {
            System.debug('saveFile error: ' + e.getMessage() + ' line ' + e.getLineNumber());
            throw new AuraHandledException('Save failed: ' + e.getMessage());
        }

        return result;
    }
}