//
//  SpeechSynthesizerManager.swift
//  Noria-AR
//
//  Created by Jesus Ariza on 2025-04-28.
//

import AVFoundation

class SpeechSynthesizerManager {

    let sintetizador = AVSpeechSynthesizer()

    func hablar(mensaje: String) {
        let utterance = AVSpeechUtterance(string: mensaje)
        utterance.voice = AVSpeechSynthesisVoice(language: "es-CO")
        sintetizador.speak(utterance)
    }
}
