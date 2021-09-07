//
//  NuclearObjects.swift
//  NuclearObjects
//
//  Created by Ben Gottlieb on 9/5/21.
//

import Foundation

public protocol ReversibleNuclearObject {} 		// confirm to this if an object's phase can both increase and decrease
public protocol VersionedNucleus: Codable {
	associatedtype Phase: Codable & Comparable
	var version: Int { get set }
	var id: String { get set }
	
	var phonePhase: Phase { get set }
	var watchPhase: Phase { get set }
}

public extension VersionedNucleus {
	var currentPhase: Phase { phonePhase > watchPhase ? phonePhase : watchPhase }
	mutating func setDevicePhase(_ phase: Phase) {
		#if os(iOS)
			phonePhase = phase
		#endif
		#if os(watchOS)
			watchPhase = phase
		#endif
	}
	
	init(json: [String: Any]) throws {
		let data = try JSONSerialization.data(withJSONObject: json, options: [])
		self = try JSONDecoder().decode(Self.self, from: data)
	}
}

public protocol NuclearObject: AnyObject {
	associatedtype Nucleus: VersionedNucleus
	var nucleus: Nucleus { get set }
	
	func phaseChanged(from oldPhase: Nucleus.Phase, to newPhase: Nucleus.Phase, locally: Bool)
}

public extension NuclearObject {
	typealias Phase = Nucleus.Phase
	func incrementVersion() {
		nucleus.version += 1
	}

	func advance(from oldPhase: Phase, to phase: Phase) {
		if phase <= oldPhase { return }
		nucleus.setDevicePhase(phase)
		incrementVersion()
		phaseChanged(from: oldPhase, to: phase, locally: true)
	}

	func advance(to phase: Phase) {
		advance(from: nucleus.currentPhase, to: phase)
	}

	func load(nucleus new: Nucleus) {
		if new.id != nucleus.id || new.version < nucleus.version { return }  		// hasn't updated
		
		let old = nucleus
		self.nucleus = new
		
		if old.currentPhase > new.currentPhase {
			nucleus.setDevicePhase(new.currentPhase)
			phaseChanged(from: old.currentPhase, to: new.currentPhase, locally: false)
		}
	}
	
	func load(nucleus json: [String: Any]) throws {
		let new = try Nucleus(json: json)
		if new.version < nucleus.version { return }  		// hasn't updated
		
		let old = nucleus
		self.nucleus = new
		
		if old.currentPhase > new.currentPhase, !(self is ReversibleNuclearObject) { return }
		if old.currentPhase != new.currentPhase {
			nucleus.setDevicePhase(new.currentPhase)
			phaseChanged(from: old.currentPhase, to: new.currentPhase, locally: false)
		}
	}
	
	var nuclearJSON: [String: Any]? {
		get {
			do {
				let data = try JSONEncoder().encode(nucleus)
				let output = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
				return output
			} catch {
				print("Failed to encode \(self): \(error)")
				return nil
			}
		}
		set {
			guard let dict = newValue else { return }
			do {
				let data = try JSONSerialization.data(withJSONObject: dict, options: [])
				let new = try JSONDecoder().decode(Nucleus.self, from: data)
				self.load(nucleus: new)
			} catch {
				print("Failed to decode \(dict): \(error)")
			}
		}
	}
}
