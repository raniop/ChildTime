//
//  FamilyPlaceTests.swift
//  ChildTimeTests
//
//  📍 Places (Rani, 2026-10-07): a fence is a circle, the nearest wins when two
//  overlap, and the household doc carries them both ways.
//

import Testing
import Foundation
@testable import ChildTime

@Suite struct FamilyPlaces {
    let school = FamilyPlace(id: "s", name: "בית הספר", emoji: "🏫", lat: 32.0800, lng: 34.7800, radius: 200)
    let home = FamilyPlace(id: "h", name: "הבית", emoji: "🏠", lat: 32.0815, lng: 34.7800, radius: 200)

    @Test func distanceIsInMeters() {
        // 0.001° of latitude ≈ 111 m.
        let m = FamilyPlace.meters(32.0800, 34.78, 32.0810, 34.78)
        #expect(abs(m - 111) < 2)
    }

    @Test func insideAndOutside() {
        #expect(school.contains(lat: 32.0805, lng: 34.7800))      // ~55 m
        #expect(!school.contains(lat: 32.0830, lng: 34.7800))     // ~333 m
    }

    @Test func overlappingPlacesPickTheNearest() {
        // Between the two (both within 200 m), closer to home.
        let p = FamilyPlace.place(at: 32.0811, 34.7800, in: [school, home])
        #expect(p?.id == "h")
        #expect(FamilyPlace.place(at: 32.1, 34.9, in: [school, home]) == nil)
    }

    @Test func householdDecodesPlacesAndOldDocsStillDecode() throws {
        var raw: [String: Any] = ["id": "hh", "parentUIDs": ["u"], "childIDs": [], "createdBy": "u",
                                  "createdAt": 0, "places": [school.firestore]]
        let data = try JSONSerialization.data(withJSONObject: raw)
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .secondsSince1970
        let hh = try dec.decode(Household.self, from: data)
        #expect(hh.places == [school])
        raw["places"] = nil
        let old = try dec.decode(Household.self, from: try JSONSerialization.data(withJSONObject: raw))
        #expect(old.places == nil)
    }
}
