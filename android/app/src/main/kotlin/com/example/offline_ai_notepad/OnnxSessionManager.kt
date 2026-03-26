package com.example.offline_ai_notepad

import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtException
import ai.onnxruntime.OrtSession
import java.io.File
import org.json.JSONObject

class OnnxSessionManager {
    private var environment: OrtEnvironment? = null
    private var summarySession: OrtSession? = null
    private var summaryModelPath: String? = null
    private var summaryInputNames: List<String> = emptyList()
    private var summaryOutputNames: List<String> = emptyList()
    private var summaryMaxSequenceLength: Int? = null
    private var tokenizerPath: String? = null
    private var tokenizerVocab: Map<String, Int> = emptyMap()

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

    fun inspectSummaryContract(
        modelPath: String,
        expectedInputNames: List<String> = emptyList(),
        expectedOutputNames: List<String> = emptyList(),
        maxSequenceLength: Int? = null,
    ): Map<String, Any> {
        val ready = ensureSummarySession(
            modelPath = modelPath,
            inputNames = expectedInputNames,
            outputNames = expectedOutputNames,
            maxSequenceLength = maxSequenceLength,
        )
        if (!ready || summarySession == null) {
            return mapOf(
                "available" to false,
                "matchesManifest" to false,
                "actualInputNames" to emptyList<String>(),
                "actualOutputNames" to emptyList<String>(),
                "message" to "Summary session is unavailable for contract inspection.",
            )
        }

        val actualInputNames = summarySession!!.inputInfo.keys.toList().sorted()
        val actualOutputNames = summarySession!!.outputInfo.keys.toList().sorted()
        val manifestInputs = expectedInputNames.sorted()
        val manifestOutputs = expectedOutputNames.sorted()
        val matchesManifest =
            (manifestInputs.isEmpty() || manifestInputs == actualInputNames) &&
                (manifestOutputs.isEmpty() || manifestOutputs == actualOutputNames)

        return mapOf(
            "available" to true,
            "matchesManifest" to matchesManifest,
            "actualInputNames" to actualInputNames,
            "actualOutputNames" to actualOutputNames,
            "message" to if (matchesManifest) {
                "Native ONNX session contract matches the manifest."
            } else {
                "Native ONNX session contract differs from the manifest."
            },
        )
    }

    fun previewTokenization(
        modelPath: String,
        tokenizerPath: String?,
        title: String?,
        body: String,
        maxSequenceLength: Int? = null,
        padTokenId: Int? = null,
        unkTokenId: Int? = null,
        bosTokenId: Int? = null,
        eosTokenId: Int? = null,
    ): Map<String, Any> {
        if (!ensureSummarySession(modelPath, maxSequenceLength = maxSequenceLength)) {
            return mapOf(
                "ready" to false,
                "inputIds" to emptyList<Int>(),
                "attentionMask" to emptyList<Int>(),
                "sequenceLength" to 0,
                "message" to "Summary session is unavailable for tokenization preview.",
            )
        }

        val tokenizerLoaded = loadTokenizer(tokenizerPath)
        val effectiveMaxLength = (maxSequenceLength ?: 32).coerceAtLeast(4)
        val content = listOfNotNull(title?.trim(), body.trim())
            .joinToString(" ")
            .replace(Regex("\\s+"), " ")
            .trim()

        val tokens = if (content.isBlank()) {
            emptyList()
        } else {
            content.split(" ")
        }

        val inputIds = mutableListOf<Int>()
        val attentionMask = mutableListOf<Int>()

        bosTokenId?.let {
            inputIds.add(it)
            attentionMask.add(1)
        }

        val budget = effectiveMaxLength - inputIds.size - if (eosTokenId != null) 1 else 0
        for (token in tokens.take(budget.coerceAtLeast(0))) {
            val normalized = token.trim()
            val tokenId = if (normalized.isBlank()) {
                unkTokenId ?: 100
            } else {
                resolveTokenId(
                    token = normalized,
                    unkTokenId = unkTokenId ?: 100,
                )
            }
            inputIds.add(tokenId)
            attentionMask.add(1)
        }

        eosTokenId?.let {
            if (inputIds.size < effectiveMaxLength) {
                inputIds.add(it)
                attentionMask.add(1)
            }
        }

        while (inputIds.size < effectiveMaxLength) {
            inputIds.add(padTokenId ?: 0)
            attentionMask.add(0)
        }

        return mapOf(
            "ready" to true,
            "inputIds" to inputIds,
            "attentionMask" to attentionMask,
            "sequenceLength" to effectiveMaxLength,
            "tokenizerLoaded" to tokenizerLoaded,
            "message" to if (tokenizerLoaded) {
                "Tokenizer preview generated with staged tokenizer vocab lookup."
            } else {
                "Tokenizer preview generated through fallback token hashing."
            },
        )
    }

    fun inspectTokenizer(tokenizerPath: String): Map<String, Any> {
        val tokenizerFile = File(tokenizerPath)
        if (!tokenizerFile.exists()) {
            return mapOf(
                "available" to false,
                "vocabSize" to 0,
                "message" to "Tokenizer file was not found on disk.",
            )
        }

        return try {
            val raw = tokenizerFile.readText()
            val json = JSONObject(raw)
            val model = json.optJSONObject("model")
            val vocab = model?.optJSONObject("vocab")
            val vocabSize = vocab?.length() ?: 0
            val preTokenizer = json.optJSONObject("pre_tokenizer")
            val normalizer = json.optJSONObject("normalizer")

            mapOf(
                "available" to true,
                "vocabSize" to vocabSize,
                "modelType" to model?.optString("type"),
                "preTokenizerType" to preTokenizer?.optString("type"),
                "normalizerType" to normalizer?.optString("type"),
                "message" to "Tokenizer metadata loaded successfully.",
            )
        } catch (error: Exception) {
            mapOf(
                "available" to false,
                "vocabSize" to 0,
                "message" to "Tokenizer metadata could not be parsed: ${error.message}",
            )
        }
    }

    private fun loadTokenizer(path: String?): Boolean {
        if (path.isNullOrBlank()) {
            tokenizerPath = null
            tokenizerVocab = emptyMap()
            return false
        }

        if (tokenizerPath == path && tokenizerVocab.isNotEmpty()) {
            return true
        }

        val tokenizerFile = File(path)
        if (!tokenizerFile.exists()) {
            tokenizerPath = path
            tokenizerVocab = emptyMap()
            return false
        }

        return try {
            val raw = tokenizerFile.readText()
            val json = JSONObject(raw)
            val model = json.optJSONObject("model")
            val vocab = model?.optJSONObject("vocab")
            val parsed = mutableMapOf<String, Int>()
            if (vocab != null) {
                val keys = vocab.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    parsed[key] = vocab.optInt(key)
                }
            }
            tokenizerPath = path
            tokenizerVocab = parsed
            parsed.isNotEmpty()
        } catch (_: Exception) {
            tokenizerPath = path
            tokenizerVocab = emptyMap()
            false
        }
    }

    private fun resolveTokenId(token: String, unkTokenId: Int): Int {
        if (tokenizerVocab.isNotEmpty()) {
            tokenizerVocab[token]?.let { return it }
            tokenizerVocab[token.lowercase()]?.let { return it }
            return unkTokenId
        }
        return ((token.lowercase().hashCode().toLong() and 0x7fffffff) % 30000).toInt() + 1000
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
            tokenizerPath = null
            tokenizerVocab = emptyMap()
        }
    }
}
