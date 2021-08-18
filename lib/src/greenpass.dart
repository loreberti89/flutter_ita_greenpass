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
    String prefix = "HC1:";
    late String ci;
    late DateTime expiration;
    String TRUST_LIST_URL = 'https://raw.githubusercontent.com/bcsongor/covid-pass-verifier/35336fd3c0ff969b5b4784d7763c64ead6305615/src/data/certificates.json'; //get from https://github.com/ministero-salute/dcc-utils/blob/master/examples/verify_signature_from_list.js

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

        Map payload = Map<String, dynamic>.from(decodedData[-260][1]);
        this.ci = payload["v"].first["ci"];
        this.version = payload["ver"];
        this.dob = payload["dob"];
        this.name = payload["nam"]["gn"];
        this.surname = payload["nam"]["fn"];

    }

    bool isPassExpired(){
        var now = DateTime.now();
        return now.isAfter(this.expiration);

    }
    Future<bool> isValidSignatureOnSite(api_url) async{
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
        ci
    ];








}