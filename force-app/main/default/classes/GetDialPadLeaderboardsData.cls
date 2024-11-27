public class GetDialPadLeaderboardsData implements Database.Batchable<string>, Database.Stateful, Database.AllowsCallouts {
    public string statusProcess = '';

    public iterable<string> start(Database.BatchableContext bc) {
        return new list<string>{'Lets Begin'};
    }
    
    public void execute(Database.BatchableContext bc, List<string> scope) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('https://dialpad.com/api/v2/stats?apikey=w6E5Apc3JZVYW3WA8DZG6d2QdFTaavLUy9PvgGjAACaPEC9b9RwZuBT9LJeEWTmkq5Ur33tznD28NRP7SXJGezqUb2K3twJWjYaE');
        request.setMethod('POST');
        request.setHeader('Accept', 'application/json');
        request.setHeader('Content-Type', 'application/json');
        request.setBody('{' +
                        /*'"is_today": true,'+ */
                        '"export_type": "stats",' +
                        '"days_ago_start": 731,'+
                        '"days_ago_end": 1095,'+
                        '"stat_type": "calls",' +
                        '"timezone": "UTC",' +
                        '"group_by": "user"' +      
                        '}');
        
        try {
            HttpResponse response = http.send(request);
            system.debug('resposne1:' + response.getBody());
            if (response.getStatusCode() == 200) {
                
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                if (responseMap.containsKey('request_id')) {
                    String requestId = (String) responseMap.get('request_id');
                    HttpRequest request2 = new HttpRequest();
                    String endpoint2 = 'https://dialpad.com/api/v2/stats/' + requestId + '?apikey=w6E5Apc3JZVYW3WA8DZG6d2QdFTaavLUy9PvgGjAACaPEC9b9RwZuBT9LJeEWTmkq5Ur33tznD28NRP7SXJGezqUb2K3twJWjYaE';
                    request2.setEndpoint(endpoint2);
                    request2.setMethod('GET');
                    request2.setHeader('accept', 'application/json');
                    HttpResponse response2 = http.send(request2);
                    system.debug('resposne2:' + response2.getBody());
                   
                    if (response2.getStatusCode() == 200) {
                       Map<String, Object> responseMap2 = (Map<String, Object>) JSON.deserializeUntyped(response2.getBody());
                        if(responseMap2.containsKey('status') && responseMap2.get('status') == 'processing'){
                            statusProcess = (STRING)responseMap2.get('status');
                            RETURN;
                        }
                        if (responseMap2.containsKey('download_url')) {
                            String endpoint3 = responseMap2.get('download_url').toString();
                            HttpRequest request3 = new HttpRequest();
                            request3.setEndpoint(endpoint3);
                            request3.setMethod('GET');
                            HttpResponse response3 = http.send(request3);
                            system.debug('resposne3:' + response3.getBody());
                            if (response3.getStatusCode() == 200) {
                                parseCsvAndStore(response3.getBody());
                            } else {
                                System.debug('Callout failed with status3: ' + response3.getStatus() + ' and body3: ' + response3.getBody());
                            }
                        }
                    } else {
                        System.debug('Callout failed with status2: ' + response2.getStatus() + ' and body2: ' + response2.getBody());
                    }
                }
            } else {
                System.debug('Callout failed with status: ' + response.getStatus() + ' and body: ' + response.getBody());
            }
        } catch (Exception e) {
            System.debug('Error during callout: ' + e.getMessage());
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        IF(statusProcess == 'processing'){
            GetDialPadLeaderboardsData sameBat = new GetDialPadLeaderboardsData();
            Database.executeBatch(sameBat, 1); 
            System.debug('Processing status came batch runing again.');
        }
        System.debug('Batch job completed.');
    }
    
    private void parseCsvAndStore(String csvContent) {
        List<String> lines = new List<String>();
        String currentLine = '';
    
        // Split CSV content into lines manually
        for (Integer i = 0; i < csvContent.length(); i++) {
            String character = csvContent.substring(i, i + 1);
            if (character == '\n') {
                lines.add(currentLine);
                currentLine = '';
            } else {
                currentLine += character;
            }
        }
        if (currentLine!='') {
            lines.add(currentLine);
        }
    
        if (lines.size() > 1) {
            // Parse headers to find column indices
            List<String> headers = lines[0].split(',');
            Integer nameIndex = headers.indexOf('name');
            Integer emailIndex = headers.indexOf('email');
            Integer userIdIndex = headers.indexOf('user_id');
            Integer dateIndex = headers.indexOf('date');
            Integer allCallsIndex = headers.indexOf('all_calls');
            Integer talkDurationIndex = headers.indexOf('talk_duration');
            Integer avgTalkDurationIndex = headers.indexOf('avg_talk_duration');
            Integer answeredIndex = headers.indexOf('answered');
            Integer missedIndex = headers.indexOf('missed');
            Integer abandonedIndex = headers.indexOf('abandoned');
            Integer cancelledIndex = headers.indexOf('cancelled');
            Integer hourIndex = headers.indexOf('hour');
    
            List<Leaderboard_Dialpad__c> recordsToInsert = new List<Leaderboard_Dialpad__c>();
    
            // Parse rows and extract relevant data
            for (Integer i = 1; i < lines.size(); i++) {
                List<String> row = lines[i].split(',');
                
                if (row.size() != headers.size() || String.isBlank(row[nameIndex])) {
                    continue; // Skip invalid rows
                }
                
                Leaderboard_Dialpad__c record = new Leaderboard_Dialpad__c();
                record.Name = row[nameIndex];
                record.Email__c = row[emailIndex];
                record.User_ID__c = row[userIdIndex];
                record.Date__c = Date.valueOf(row[dateIndex]);
                record.All_Calls__c = Integer.valueOf(row[allCallsIndex]);
                record.Talk_Duration__c = Decimal.valueOf(row[talkDurationIndex]);
                record.Avg_Talk_Duration__c = Decimal.valueOf(row[avgTalkDurationIndex]);
                if(answeredIndex!=-1){
                     record.Answered__c = Integer.valueOf(row[answeredIndex]);
                }
                if(hourIndex!=-1){
                  record.hour__c = Integer.valueOf(row[hourIndex]);  
                }
                record.Missed__c = Integer.valueOf(row[missedIndex]);
                record.Abandoned__c = Integer.valueOf(row[abandonedIndex]);
                record.Cancelled__c = Integer.valueOf(row[cancelledIndex]);
                recordsToInsert.add(record);
            }
    
            if (!recordsToInsert.isEmpty()) {
                insert recordsToInsert;
                System.debug('Inserted ' + recordsToInsert.size() + ' records.');
            } else {
                System.debug('No valid records to insert.');
            }
        }
    }
 }