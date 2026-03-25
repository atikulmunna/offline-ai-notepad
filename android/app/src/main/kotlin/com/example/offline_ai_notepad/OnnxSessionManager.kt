package com.example.offline_ai_notepad

import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtException
import ai.onnxruntime.OrtSession
import java.io.File

class OnnxSessionManager {
    private var environment: OrtEnvironment? = null
    private var summarySession: OrtSession? = null
    private var summaryModelPath: String? = null
    private var summaryInputNames: List<String> = emptyList()
    private var summaryOutputNames: List<String> = emptyList()
    private var summaryMaxSequenceLength: Int? = null

    fun ensureSummarySession(
        modelPath: String,
        inputNames: List<String> = emptyList(),
        outputNames: List<String> = emptyList(),
        maxSequenceLength: Int? = null,
    ): Boolean {
        val modelFile = File(modelPath)
        if (!modelFile.exists()) {
            return false
        }

        if (
            summarySession != null &&
            summaryModelPath == modelPath &&
            summaryInputNames == inputNames &&
            summaryOutputNames == outputNames &&
            summaryMaxSequenceLength == maxSequenceLength
        ) {
            return true
        }

        closeSummarySession()

        val env = environment ?: OrtEnvironment.getEnvironment().also {
            environment = it
        }

        return try {
            summarySession = env.createSession(
                modelFile.absolutePath,
                OrtSession.SessionOptions(),
            )
            summaryModelPath = modelFile.absolutePath
            summaryInputNames = inputNames
            summaryOutputNames = outputNames
            summaryMaxSequenceLength = maxSequenceLength
            true
        } catch (_: OrtException) {
            closeSummarySession()
            false
        }
    }

    fun generateSummaryPlaceholder(
        title: String?,
        body: String,
        modelPath: String,
        inputNames: List<String> = emptyList(),
        outputNames: List<String> = emptyList(),
        maxSequenceLength: Int? = null,
    ): String? {
        if (!ensureSummarySession(modelPath, inputNames, outputNames, maxSequenceLength)) {
            return null
        }

        val normalized = body.replace(Regex("\\s+"), " ").trim()
        if (normalized.isEmpty()) {
            return "Native ONNX bridge is ready, but this note is still empty."
        }

        val lead = if (title.isNullOrBlank()) {
            "Native ONNX session active:"
        } else {
            "${title.trim()}:"
        }
        val preview = normalized.take(180)
        val ioHint = buildString {
            if (inputNames.isNotEmpty()) {
                append(" Inputs=${inputNames.joinToString(",")}.")
            }
            if (outputNames.isNotEmpty()) {
                append(" Outputs=${outputNames.joinToString(",")}.")
            }
            if (maxSequenceLength != null) {
                append(" MaxSeq=$maxSequenceLength.")
            }
        }.trim()
        return listOf(lead, preview, ioHint).where { it.isNotBlank() }.joinToString(" ")
    }

    private fun closeSummarySession() {
        try {
            summarySession?.close()
        } catch (_: Exception) {
        } finally {
            summarySession = null
            summaryModelPath = null
            summaryInputNames = emptyList()
            summaryOutputNames = emptyList()
            summaryMaxSequenceLength = null
        }
    }
}
