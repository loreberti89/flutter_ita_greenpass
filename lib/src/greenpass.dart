import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:cbor/cbor.dart';
import 'package:dart_base45/dart_base45.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;

class Greenpass extends Equatable{

    late String _raw;
    late List<int> inflated;
    late Map payload;
    late String name;

    late String surname;
    late String version;
    late String dob;


    late String vaccineType;
    late int doseNumber;
    late int totalSeriesOfDoses;
    late String dateOfVaccination;
    late String ci;
    late DateTime expiration;


    final APP_MIN_VERSION = "android";
    final RECOVERY_CERT_START_DAY = "recovery_cert_start_day";
    final RECOVERY_CERT_END_DAY = "recovery_cert_end_day";
    final MOLECULAR_TEST_START_HOUR = "molecular_test_start_hours";
    final MOLECULAR_TEST_END_HOUR = "molecular_test_end_hours";
    final RAPID_TEST_START_HOUR = "rapid_test_start_hours";
    final RAPID_TEST_END_HOUR = "rapid_test_end_hours";
    final VACCINE_START_DAY_NOT_COMPLETE = "vaccine_start_day_not_complete";
    final VACCINE_END_DAY_NOT_COMPLETE = "vaccine_end_day_not_complete";
    final VACCINE_START_DAY_COMPLETE = "vaccine_start_day_complete";
    final VACCINE_END_DAY_COMPLETE = "vaccine_end_day_complete";
    final String prefix = "HC1:";
    final String urlRules = "https://get.dgc.gov.it/v1/dgc/settings";
    final String TRUST_LIST_URL = 'https://raw.githubusercontent.com/bcsongor/covid-pass-verifier/35336fd3c0ff969b5b4784d7763c64ead6305615/src/data/certificates.json'; //get from https://github.com/ministero-salute/dcc-utils/blob/master/examples/verify_signature_from_list.js

    final String NOT_DETECTED = "260415000";
    final String NOT_VALID_YET= "Not valid yet";
    final String VALID= "Valid";
    final String NOT_VALID= "Not valid";
    final String NOT_GREEN_PASS= "Not a green pass";
    final String PARTIALLY_VALID = "Valid only in Italy";
    //values get from https://github.com/eu-digital-green-certificates/dgca-app-core-android/blob/b9ba5b3bc7b8f1c510a79d07bbaecae8a6edfd74/decoder/src/main/java/dgca/verifier/app/decoder/model/Test.kt
    final String DETECTED = "260373001";

    final String TEST_RAPID = "LP217198-3";
    final String TEST_MOLECULAR = "LP6464-4";
    Map rules;

    Greenpass();

    void decodeFromRaw(String code){
        this._raw = code;
        Uint8List decodedBase45 = Base45.decode(this._raw.substring(this.prefix.length));
        inflated = ZLibDecoder().decodeBytes(decodedBase45);
        Cbor cbor = Cbor();
        cbor.decodeFromList(inflated);
        List<dynamic>? rawDecodification = cbor.getDecodedData();
        cbor.clearDecodeStack();

        cbor.decodeFromList(rawDecodification![0][2]);

        Map decodedData = Map<dynamic, dynamic>.from(cbor.getDecodedData()![0]);

        this.expiration = DateTime.fromMillisecondsSinceEpoch(decodedData[4] * 1000); //is timestamp

        payload = Map<String, dynamic>.from(decodedData[-260][1]);

        if(payload.containsKey("r")){
            this.ci = payload["r"].first["ci"];
        }
        if(payload.containsKey("v")){
            this.vaccineType = payload["v"].first["mp"];
            this.doseNumber = payload["v"].first["dn"];
            this.dateOfVaccination = payload["v"].first["dt"];
            this.totalSeriesOfDoses = payload["v"].first["sd"];
            this.ci = payload["v"].first["ci"];
        }
        if(payload.containsKey("t")){
            this.ci = payload["t"].first["ci"];
        }


        this.version = payload["ver"];
        this.dob = payload["dob"];
        this.name = payload["nam"]["gn"];
        this.surname = payload["nam"]["fn"];

    }

    getVaccineEndDayComplete(rules, vaccineType){
        var rule = null;
        for(int i = 0; i < rules.length; i++){
            if(rules[i]["name"] == VACCINE_END_DAY_COMPLETE && rules[i]["type"] == vaccineType){
                rule = rules[i];
            }
        }
        return rule;
    }

    getVaccineStartDayNotComplete(rules, vaccineType){
        var rule = null;
        for(int i = 0; i < rules.length; i++){
            if(rules[i]["name"] == VACCINE_START_DAY_NOT_COMPLETE && rules[i]["type"] == vaccineType){
                rule = rules[i];
            }
        }
        return rule;
    }
    getVaccineEndDayNotComplete(rules, vaccineType){
        var rule = null;
        for(int i = 0; i < rules.length; i++){
            if(rules[i]["name"] == VACCINE_END_DAY_NOT_COMPLETE && rules[i]["type"] == vaccineType){
                rule = rules[i];
            }
        }
        return rule;
    }

    getVaccineStartDayComplete(rules, vaccineType){
        var rule = null;
        for(int i = 0; i < rules.length; i++){
            if(rules[i]["name"] == VACCINE_START_DAY_COMPLETE && rules[i]["type"] == vaccineType){
                rule = rules[i];
            }
        }
        return rule;
    }

    getRapidTestStartHour(rules) {
        var rule = null;
        for(int i = 0; i < rules.length; i++){
            if(rules[i]["name"] == RAPID_TEST_START_HOUR){
                rule = rules[i];
            }
        }
        return rule;


    }

    getMolecularTestStartHour(rules) {
        var rule = null;
        for(int i = 0; i < rules.length; i++){
            if(rules[i]["name"] == MOLECULAR_TEST_START_HOUR){
                rule = rules[i];
            }
        }
        return rule;

    }
    getMolecularTestEndHour(rules){
        var rule = null;
        for(int i = 0; i < rules.length; i++){
            if(rules[i]["name"] == MOLECULAR_TEST_END_HOUR){
                rule = rules[i];
            }
        }
        return rule;

    }

    getRapidTestEndHour(rules) {
        var rule = null;
        for(int i = 0; i < rules.length; i++){
            if(rules[i]["name"] == RAPID_TEST_END_HOUR){
                rule = rules[i];
            }
        }
        return rule;
    }

    bool isPassExpired(){
        var now = DateTime.now();
        return now.isAfter(this.expiration);

    }

    /* Function from VERIFICA-C19 */
    checkTests(rules){
        var obj = payload['t'].last();
        String message = "";
        var result = false;
        var now = DateTime.now();
        if (obj['tr'] == DETECTED) {
            message = NOT_VALID;
        }else{
            try {
                var typeOfTest = obj['tt'];

                //in app Verifica C-19 get data and parse in UTC and then parse in Local
                var odtDateTimeOfCollection = DateTime.utc(obj['sc']);
                var ldtDateTimeOfCollection = odtDateTimeOfCollection.toLocal();
                DateTime startDate;
                DateTime endDate;


                if(typeOfTest == TEST_MOLECULAR){
                    var daysStart = getMolecularTestStartHour(rules)["value"];
                    var daysEnd = getMolecularTestEndHour(rules)["value"];
                    startDate = ldtDateTimeOfCollection.add(Duration(hours: int.parse(daysStart)));
                    endDate = ldtDateTimeOfCollection.add(Duration(hours: int.parse(daysEnd)));


                }else{ //if not MOLECULAR IS RAPID FOR NOW
                    var daysStart = getRapidTestStartHour(rules)["value"];
                    var daysEnd = getRapidTestEndHour(rules)["value"];
                    startDate = ldtDateTimeOfCollection.add(Duration(hours: int.parse(daysStart)));
                    endDate = ldtDateTimeOfCollection.add(Duration(hours: int.parse(daysEnd)));
                }




                if(startDate.isAfter(now)){
                    message = NOT_VALID_YET;
                }else if(now.isAfter(endDate)){
                    message = NOT_VALID;
                }else{
                    result = true;
                    message = VALID;
                }

            } catch (e) {
                result = false;
                message = NOT_GREEN_PASS;

            }
        }

        return {
            result,
            message
        };

    }


    /* Function from VERIFICA-C19 */
    checkRecoveryStatements(){
        var obj = payload['r'].last();
        DateTime now = DateTime.now();
        String message = "";
        bool result = false;
        try {
            var startDate = DateTime.parse(obj['df']);
            var endDate  =DateTime.parse(obj['du']);
            if(startDate.isAfter(now)){
                message = NOT_VALID_YET;
            }else if(now.isAfter(endDate)){
                message = NOT_VALID;
            }else{
                result = true;
                message = VALID;
            };
        } catch (e) {
            result = false;
            message = NOT_VALID;

        }
        return {
            result,
            message
        };

    }

    Future fetchRules() async{
        var response = await Dio().get(urlRules);
        rules = response.data;
    }

    Future<dynamic> isValid() async {

        try {

            if(payload.containsKey("r")){
               return checkRecoveryStatements();
            }
            if(payload.containsKey("v")){
                return isValidRule(rules);
            }
            if(payload.containsKey("t")){
                return checkTests(rules);
            }


        }catch(e){
            return {"result":false, "message":e};
        }

    }

    //this function is translated in DART from VERIFICA C-19 and get only rules ita.
    Future<dynamic> isValidRule(rules) async{

        var now = DateTime.now();
        try{

            String message = "";
            bool result = false;
            var rule = getVaccineEndDayComplete(rules, vaccineType);


            if(rule != null){
                try{
                    if(doseNumber < totalSeriesOfDoses){
                        var daysStart = getVaccineStartDayNotComplete(rules, vaccineType)["value"];
                        var daysEnd = getVaccineEndDayNotComplete(rules, vaccineType)["value"];
                        DateTime startDate = DateTime.parse(dateOfVaccination).add(Duration(days: int.parse(daysStart)));
                        DateTime endDate = DateTime.parse(dateOfVaccination).add(Duration(days: int.parse(daysEnd)));
                        if(startDate.isAfter(now)){
                            message = "not valid yet";
                        }else{
                            result = true;
                            message = "partially valid";
                        }
                    }else
                    if(doseNumber >= totalSeriesOfDoses){
                        var daysStart = getVaccineStartDayComplete(rules, vaccineType)["value"];
                        var daysEnd = getVaccineEndDayComplete(rules, vaccineType)["value"];
                        DateTime startDate = DateTime.parse(dateOfVaccination).add(new Duration(days: int.parse(daysStart)));
                        DateTime endDate = DateTime.parse(dateOfVaccination).add(new Duration(days: int.parse(daysEnd)));
                        if(startDate.isAfter(now)){
                            message = "not valid yet";
                        }else{
                            result = true;
                            message = "valid";
                        }
                    }else{
                        result = false;
                        message = "not valid";
                    }
                }catch (e){
                    result = false;
                    message = "not valid";
                }
            }else{
                result = false;
                message = "not valid";
            }
            return {"result":result, "message":message};
        }catch(e){
            return {"result":false, "message":e};
        }

    }

    Future<bool> isValidSignatureOnSite(api_url, code) async{
        //For Now I have put a Call to my backend and then make a Validation From NodejS trascrition of dcc-utils
        //The translation from JS dcc-utils and DART for the validation was complicated for now and my deadline :)
        // but in future can be implemented
        try {
            var response = await Dio().post(api_url+"/checkGreenPass", data: {"code": code});
            return response.data["valid"];
        }catch(e){
            print(e);
            return false;
        }

        /*http.Response response = await http.get(this.TRUST_LIST_URL);
        var signatures = jsonDecode(response.body);
        for (Map<dynamic, dynamic> signature  in signatures) {
            if (signature.containsKey("pub")) {
                try {
                    bool verified = await this.checkSignature({
                        "x": signature['pub']["x"],
                        "y": signature['pub']["y"],
                        "kid": signature["kid"],
                    });
                    if (verified) {
                        // console.log(dcc.payload);

                        break;
                    }
                } catch(e) {

                }
            }
        }*/





    }

    @override
    List<Object> get props => [
        name,
        surname,
        dob,
        ci,
        vaccineType,
        doseNumber,
        totalSeriesOfDoses,
        dateOfVaccination,
        dateOfVaccination
    ];








}