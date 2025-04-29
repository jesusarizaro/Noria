//
//  VoiceManager.swift
//  Noria-AR
//
//  Created by Jesus Ariza on 2025-04-08.
//

import Speech

class VoiceManager {

    func solicitarPermisos() {
        SFSpeechRecognizer.requestAuthorization { estatus in
            switch estatus {
            case .authorized:
                print("Reconocimiento de voz autorizado.")
            default:
                print("Reconocimiento de voz denegado.")
            }
        }
    }
}
