//
//  DriverInfo.swift
//  pitwall-ios
//
//  Created by Robin on 22/7/23.
//

import Foundation

struct DriverInfo {
    
    struct infoStruct {
        let rNum: Int
        let fName: String
        let sName: String
        let tShort: String
        let tLong: String
    }
    
    let lookup: [String:infoStruct] = [
        "1": infoStruct(rNum: 1, fName: "Max Verstappen", sName: "VER", tShort: "RBR", tLong: "Red Bull Racing"),
        "11": infoStruct(rNum: 11, fName: "Sergio Perez", sName: "PER", tShort: "RBR", tLong: "Red Bull Racing"),
        "14": infoStruct(rNum: 14, fName: "Fernando Alonso", sName: "ALO", tShort: "AST", tLong: "Aston Martin"),
        "18": infoStruct(rNum: 18, fName: "Lance Stroll", sName: "STR", tShort: "AST", tLong: "Aston Martin"),
        "44": infoStruct(rNum: 44, fName: "Lewis Hamilton", sName: "HAM", tShort: "MER", tLong: "Mercedes"),
        "63": infoStruct(rNum: 63, fName: "George Russell", sName: "RUS", tShort: "MER", tLong: "Mercedes"),
        "16": infoStruct(rNum: 16, fName: "Charles Leclerc", sName: "LEC", tShort: "FER", tLong: "Ferrari"),
        "55": infoStruct(rNum: 55, fName: "Carlos Sainz", sName: "SAI", tShort: "FER", tLong: "Ferrari"),
        "4": infoStruct(rNum: 4, fName: "Lando Norris", sName: "NOR", tShort: "MCL", tLong: "McLaren"),
        "81": infoStruct(rNum: 81, fName: "Oscar Piastri", sName: "PIA", tShort: "MCL", tLong: "McLaren"),
        "31": infoStruct(rNum: 31, fName: "Esteban Ocon", sName: "OCO", tShort: "ALP", tLong: "Alpine"),
        "10": infoStruct(rNum: 10, fName: "Pierre Gasly", sName: "GAS", tShort: "ALP", tLong: "Alpine"),
        "23": infoStruct(rNum: 23, fName: "Alexander Albon", sName: "ALB", tShort: "WIL", tLong: "Williams"),
        "2": infoStruct(rNum: 2, fName: "Logan Sargeant", sName: "SAR", tShort: "WIL", tLong: "Williams"),
        "27": infoStruct(rNum: 27, fName: "Nico Hulkenburg", sName: "HUL", tShort: "HAA", tLong: "Haas F1 Team"),
        "20": infoStruct(rNum: 20, fName: "Kevin Magnussen", sName: "MAG", tShort: "HAA", tLong: "Haas F1 Team"),
        "77": infoStruct(rNum: 77, fName: "Valtteri Bottas", sName: "BOT", tShort: "ALF", tLong: "Alfa Romeo"),
        "24": infoStruct(rNum: 24, fName: "Guanyu Zhou", sName: "ZHO", tShort: "ALF", tLong: "Alfa Romeo"),
        "22": infoStruct(rNum: 22, fName: "Yuki Tsunoda", sName: "TSU", tShort: "ALP", tLong: "Alpha Tauri"),
        "3": infoStruct(rNum: 3, fName: "Daniel Ricciardo", sName: "RIC", tShort: "ALP", tLong: "Alpha Tauri")
        ]
}
