//
//  NuclearObjects.swift
//  NuclearObjects
//
//  Created by Ben Gottlieb on 9/5/21.
//

import Foundation

public protocol VersionedNucleus: Codable {
	associatedtype State: Codable & Comparable
	var version: Int { get set }
	
	var phoneState: State { get set }
	var watchState: State { get set }
}

public extension VersionedNucleus {
	var currentState: State { phoneState > watchState ? phoneState : watchState }
	mutating func setDeviceState(_ state: State) {
		#if os(iOS)
			phoneState = state
		#endif
		#if os(watchOS)
			watchState = state
		#endif
	}
}

public protocol NuclearObject: AnyObject {
	associatedtype Nucleus: VersionedNucleus
	var nucleus: Nucleus { get set }
	func stateChanged(from oldState: Nucleus.State, to newState: Nucleus.State)
}

public extension NuclearObject {
	func load(nucleus new: Nucleus) {
		if new.version <= nucleus.version { return }  		// hasn't updated
		
		let old = nucleus
		self.nucleus = new
		
		if old.currentState > new.currentState {
			nucleus.setDeviceState(new.currentState)
			stateChanged(from: old.currentState, to: new.currentState)
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
