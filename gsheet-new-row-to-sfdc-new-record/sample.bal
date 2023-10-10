import ballerina/http;
import ballerina/log;
import ballerinax/googleapis.sheets;
import ballerinax/salesforce as sfdc;
import ballerinax/trigger.google.sheets as sheetsListener;

// Types
type GSheetOAuth2Config record {
    string clientId;
    string clientSecret;
    string refreshToken;
    string refreshUrl = "https://www.googleapis.com/oauth2/v3/token";
};

type SalesforceOAuth2Config record {
    string clientId;
    string clientSecret;
    string refreshToken;
    string refreshUrl = "https://login.salesforce.com/services/oauth2/token";
};

// Constants
const int HEADINGS_ROW = 1;

// Google sheets configuration parameters
configurable string spreadsheetId = ?;
configurable string worksheetName = ?;
configurable GSheetOAuth2Config GSheetOAuthConfig = ?;

// Salesforce configuration parameters
configurable SalesforceOAuth2Config salesforceOAuthConfig = ?;
configurable string salesforceBaseUrl = ?;
configurable string salesforceObject = ?;

listener http:Listener httpListener = new(8090);
listener sheetsListener:Listener gSheetListener = new ({
    spreadsheetId: spreadsheetId
}, httpListener);

@display { label: "Google Sheets New Row to Salesforce New Record" }
service sheetsListener:SheetRowService on gSheetListener {
    remote function onAppendRow(sheetsListener:GSheetEvent payload) returns error? {
        if (payload?.worksheetName == worksheetName) {
            sheets:Client sheetsClient = check new ({ 
                auth: {
                    clientId: GSheetOAuthConfig.clientId,
                    clientSecret: GSheetOAuthConfig.clientSecret,
                    refreshToken: GSheetOAuthConfig.refreshToken,
                    refreshUrl: GSheetOAuthConfig.refreshUrl
                }
            });
            sheets:Row headingsRow = check sheetsClient->getRow(spreadsheetId, worksheetName, HEADINGS_ROW);
            // Get the column headings
            (int|string|decimal)[] headings = headingsRow.values;
            // Get the appended values 
            (int|string|float)[] appendedValues;
            (int|string|float)[][]? newValues = payload?.newValues;
            if newValues is () || newValues.length() == 0 {
                return;
            } else {
                appendedValues = newValues[0];
            }
            // Construct the new json record
            map<json> newRecord = {};
            foreach int index in 0 ..< headings.length() {
                newRecord[headings[index].toString()] = appendedValues[index];
            }

            sfdc:Client sfdcClient = check new ({
                baseUrl: salesforceBaseUrl,
                auth: {
                    clientId: salesforceOAuthConfig.clientId,
                    clientSecret: salesforceOAuthConfig.clientSecret,
                    refreshToken: salesforceOAuthConfig.refreshToken,
                    refreshUrl: salesforceOAuthConfig.refreshUrl
                }
            });
            // Specify the record type (sfdcObject) to create. For example an 'Account' record type.
            string createRecordResponse = check sfdcClient->createRecord(salesforceObject, newRecord);
            log:printInfo(string `Record created successfully!. Record ID : ${createRecordResponse}`);
        }
    }

    remote function onUpdateRow(sheetsListener:GSheetEvent payload) returns error? {
      return;
    }
}

service /ignore on httpListener {}
