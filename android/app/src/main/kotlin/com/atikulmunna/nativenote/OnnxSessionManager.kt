package com.atikulmunna.nativenote

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtException
import ai.onnxruntime.OrtSession
import java.io.File
import java.nio.FloatBuffer
import java.nio.LongBuffer
import kotlin.math.min
import org.json.JSONObject

class OnnxSessionManager {
    private var environment: OrtEnvironment? = null
    private var encoderSession: OrtSession? = null
    private var decoderSession: OrtSession? = null
    private var encoderModelPath: String? = null
    private var decoderModelPath: String? = null
    private var summaryInputNames: List<String> = emptyList()
    private var summaryOutputNames: List<String> = emptyList()
    private var summaryMaxSequenceLength: Int? = null
    private var tokenizerPath: String? = null
    private var tokenToId: Map<String, Int> = emptyMap()
    private var tokenScores: Map<String, Double> = emptyMap()
    private var idToToken: Map<Int, String> = emptyMap()

    fun ensureSummarySession(
        modelPath: String,
        inputNames: List<String> = emptyList(),
        outputNames: List<String> = emptyList(),
        maxSequenceLength: Int? = null,
    ): Boolean {
        val decoderFile = File(modelPath)
        val encoderFile = File(decoderFile.parentFile, "encoder_model.onnx")
        if (!decoderFile.exists() || !encoderFile.exists()) {
            return false
        }

        if (
            decoderSession != null &&
            encoderSession != null &&
            decoderModelPath == decoderFile.absolutePath &&
            encoderModelPath == encoderFile.absolutePath &&
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
            encoderSession = env.createSession(
                encoderFile.absolutePath,
                OrtSession.SessionOptions(),
            )
            decoderSession = env.createSession(
                decoderFile.absolutePath,
                OrtSession.SessionOptions(),
            )
            encoderModelPath = encoderFile.absolutePath
            decoderModelPath = decoderFile.absolutePath
            summaryInputNames = inputNames
            summaryOutputNames = outputNames
            summaryMaxSequenceLength = maxSequenceLength
            true
        } catch (_: OrtException) {
            closeSummarySession()
            false
        }
    }

    fun generateSummary(
        title: String?,
        body: String,
        modelPath: String,
        tokenizerPath: String?,
        inputNames: List<String> = emptyList(),
        outputNames: List<String> = emptyList(),
        maxSequenceLength: Int? = null,
        padTokenId: Int? = null,
        unkTokenId: Int? = null,
        bosTokenId: Int? = null,
        eosTokenId: Int? = null,
    ): String? {
        if (!ensureSummarySession(modelPath, inputNames, outputNames, maxSequenceLength)) {
            return null
        }

        val effectivePadTokenId = padTokenId ?: 0
        val effectiveUnkTokenId = unkTokenId ?: 2
        val effectiveBosTokenId = bosTokenId ?: effectivePadTokenId
        val effectiveEosTokenId = eosTokenId ?: 1
        loadTokenizer(tokenizerPath)

        val prompt = buildPrompt(title, body)
        if (prompt.isBlank()) {
            return "This note is still empty."
        }

        val encoderTokenIds = tokenizeInput(
            text = prompt,
            maxSequenceLength = maxSequenceLength ?: 256,
            eosTokenId = effectiveEosTokenId,
            unkTokenId = effectiveUnkTokenId,
        )
        if (encoderTokenIds.isEmpty()) {
            return null
        }

        val attentionMask = LongArray(encoderTokenIds.size) { 1L }
        val hiddenState = runEncoder(
            inputIds = encoderTokenIds.map(Int::toLong).toLongArray(),
            attentionMask = attentionMask,
        ) ?: return null

        val generatedIds = mutableListOf(effectiveBosTokenId)
        val minNewTokens = 12
        val maxNewTokens = 72

        repeat(maxNewTokens) {
            val nextTokenId = runDecoderStep(
                decoderIds = generatedIds.map(Int::toLong).toLongArray(),
                attentionMask = attentionMask,
                encoderHiddenState = hiddenState,
                generatedIds = generatedIds,
                eosTokenId = effectiveEosTokenId,
                minGeneratedTokens = minNewTokens,
                unkTokenId = effectiveUnkTokenId,
            ) ?: return@repeat

            if (nextTokenId == effectiveEosTokenId) {
                return@repeat
            }
            generatedIds.add(nextTokenId)
        }

        val decoded = decodeTokenIds(
            tokenIds = generatedIds,
            bosTokenId = effectiveBosTokenId,
            eosTokenId = effectiveEosTokenId,
            padTokenId = effectivePadTokenId,
            unkTokenId = effectiveUnkTokenId,
        )

        return decoded.ifBlank {
            fallbackSummary(title, body)
        }
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
        if (!ready || decoderSession == null) {
            return mapOf(
                "available" to false,
                "matchesManifest" to false,
                "actualInputNames" to emptyList<String>(),
                "actualOutputNames" to emptyList<String>(),
                "message" to "Summary session is unavailable for contract inspection.",
            )
        }

        val actualInputNames = decoderSession!!.inputInfo.keys.toList().sorted()
        val actualOutputNames = decoderSession!!.outputInfo.keys.toList().sorted()
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
                "Native ONNX decoder contract matches the manifest."
            } else {
                "Native ONNX decoder contract differs from the manifest."
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
        val prompt = buildPrompt(title, body)
        val effectiveMaxLength = (maxSequenceLength ?: 128).coerceAtLeast(8)
        val inputIds = tokenizeInput(
            text = prompt,
            maxSequenceLength = effectiveMaxLength,
            eosTokenId = eosTokenId ?: 1,
            unkTokenId = unkTokenId ?: 2,
        ).toMutableList()

        if (bosTokenId != null && inputIds.isEmpty()) {
            inputIds.add(bosTokenId)
        }

        val attentionMask = MutableList(inputIds.size) { 1 }
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

    fun previewRun(
        modelPath: String,
        tokenizerPath: String?,
        title: String?,
        body: String,
        inputNames: List<String> = emptyList(),
        outputNames: List<String> = emptyList(),
        maxSequenceLength: Int? = null,
        padTokenId: Int? = null,
        unkTokenId: Int? = null,
        bosTokenId: Int? = null,
        eosTokenId: Int? = null,
    ): Map<String, Any> {
        val tokenization = previewTokenization(
            modelPath = modelPath,
            tokenizerPath = tokenizerPath,
            title = title,
            body = body,
            maxSequenceLength = maxSequenceLength,
            padTokenId = padTokenId,
            unkTokenId = unkTokenId,
            bosTokenId = bosTokenId,
            eosTokenId = eosTokenId,
        )

        val ready = tokenization["ready"] as? Boolean ?: false
        if (!ready || encoderSession == null || decoderSession == null) {
            return mapOf(
                "ready" to false,
                "outputNames" to emptyList<String>(),
                "outputShapes" to emptyList<String>(),
                "message" to "Unable to build tensors for ONNX run preview.",
            )
        }

        val inputIds = (tokenization["inputIds"] as? List<*>)?.mapNotNull {
            (it as? Number)?.toLong()
        } ?: emptyList()
        val attentionMask = (tokenization["attentionMask"] as? List<*>)?.mapNotNull {
            (it as? Number)?.toLong()
        } ?: emptyList()
        if (inputIds.isEmpty() || attentionMask.isEmpty()) {
            return mapOf(
                "ready" to false,
                "outputNames" to emptyList<String>(),
                "outputShapes" to emptyList<String>(),
                "message" to "Tokenization preview did not produce usable tensors.",
            )
        }

        val hiddenState = runEncoder(
            inputIds = inputIds.toLongArray(),
            attentionMask = attentionMask.toLongArray(),
        ) ?: return mapOf(
            "ready" to false,
            "outputNames" to emptyList<String>(),
            "outputShapes" to emptyList<String>(),
            "message" to "Encoder session could not produce hidden states.",
        )

        return try {
            val decoderIds = longArrayOf(bosTokenId?.toLong() ?: 0L)
            val (shapes, sample) = runDecoderPreview(
                decoderIds = decoderIds,
                attentionMask = attentionMask.toLongArray(),
                encoderHiddenState = hiddenState,
            )
            mapOf(
                "ready" to true,
                "outputNames" to if (outputNames.isNotEmpty()) outputNames else listOf("logits"),
                "outputShapes" to shapes,
                "outputValueSample" to sample,
                "message" to "ONNX encoder-decoder run preview completed with raw output tensor metadata.",
            )
        } catch (error: Exception) {
            mapOf(
                "ready" to false,
                "outputNames" to emptyList<String>(),
                "outputShapes" to emptyList<String>(),
                "message" to "ONNX run preview failed: ${error.message}",
            )
        }
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
            val vocab = model?.optJSONArray("vocab")
            val vocabSize = vocab?.length() ?: 0
            val preTokenizer = json.optJSONObject("pre_tokenizer")
            val normalizer = json.optJSONObject("normalizer")

            mapOf(
                "available" to true,
                "vocabSize" to vocabSize,
                "modelType" to (model?.optString("type") ?: ""),
                "preTokenizerType" to (preTokenizer?.optString("type") ?: ""),
                "normalizerType" to (normalizer?.optString("type") ?: ""),
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

    private fun buildPrompt(title: String?, body: String): String {
        val normalizedBody = body
            .replace(Regex("\\s+"), " ")
            .replace(Regex("""[•*]\s*"""), "")
            .trim()
        val normalizedTitle = title?.replace(Regex("\\s+"), " ")?.trim()
        val clippedBody = if (normalizedBody.length > 900) {
            normalizedBody.substring(0, 900).trim()
        } else {
            normalizedBody
        }
        return buildString {
            append("Summarize this note in 2 concrete sentences. Name the subject directly, avoid vague openings like 'it' or 'this', and mention the main takeaway or outcome. ")
            if (!normalizedTitle.isNullOrBlank()) {
                append("Subject: ")
                append(normalizedTitle)
                append(". ")
            }
            append("Note: ")
            append(clippedBody)
        }.trim()
    }

    private fun loadTokenizer(path: String?): Boolean {
        if (path.isNullOrBlank()) {
            tokenizerPath = null
            tokenToId = emptyMap()
            tokenScores = emptyMap()
            idToToken = emptyMap()
            return false
        }

        if (tokenizerPath == path && tokenToId.isNotEmpty() && idToToken.isNotEmpty()) {
            return true
        }

        val tokenizerFile = File(path)
        if (!tokenizerFile.exists()) {
            tokenizerPath = path
            tokenToId = emptyMap()
            tokenScores = emptyMap()
            idToToken = emptyMap()
            return false
        }

        return try {
            val raw = tokenizerFile.readText()
            val json = JSONObject(raw)
            val model = json.optJSONObject("model")
            val vocab = model?.optJSONArray("vocab")
            val parsedTokenToId = mutableMapOf<String, Int>()
            val parsedTokenScores = mutableMapOf<String, Double>()
            val parsedIdToToken = mutableMapOf<Int, String>()
            if (vocab != null) {
                for (index in 0 until vocab.length()) {
                    val entry = vocab.optJSONArray(index) ?: continue
                    val token = entry.optString(0)
                    val score = entry.optDouble(1, Double.NEGATIVE_INFINITY)
                    parsedTokenToId[token] = index
                    parsedTokenScores[token] = score
                    parsedIdToToken[index] = token
                }
            }
            tokenizerPath = path
            tokenToId = parsedTokenToId
            tokenScores = parsedTokenScores
            idToToken = parsedIdToToken
            parsedTokenToId.isNotEmpty()
        } catch (_: Exception) {
            tokenizerPath = path
            tokenToId = emptyMap()
            tokenScores = emptyMap()
            idToToken = emptyMap()
            false
        }
    }

    private fun tokenizeInput(
        text: String,
        maxSequenceLength: Int,
        eosTokenId: Int,
        unkTokenId: Int,
    ): List<Int> {
        val normalized = text.replace(Regex("\\s+"), " ").trim()
        if (normalized.isBlank()) {
            return emptyList()
        }

        val metaspaceText = normalized
            .split(" ")
            .filter { it.isNotBlank() }
            .joinToString(separator = "") { "▁$it" }

        val pieces = if (tokenToId.isEmpty() || tokenScores.isEmpty()) {
            metaspaceText.chunked(12).map { resolveFallbackTokenId(it, unkTokenId) }.toMutableList()
        } else {
            segmentUnigramText(metaspaceText, unkTokenId).toMutableList()
        }

        if (pieces.size > maxSequenceLength - 1) {
            while (pieces.size > maxSequenceLength - 1) {
                pieces.removeAt(pieces.lastIndex)
            }
        }

        if (pieces.size < maxSequenceLength) {
            pieces.add(eosTokenId)
        }
        return pieces
    }

    private fun segmentUnigramText(source: String, unkTokenId: Int): List<Int> {
        if (source.isBlank()) {
            return emptyList()
        }

        val bestScore = DoubleArray(source.length + 1) { Double.NEGATIVE_INFINITY }
        val bestPrevious = IntArray(source.length + 1) { -1 }
        val bestTokenId = IntArray(source.length + 1) { -1 }
        bestScore[0] = 0.0

        for (start in source.indices) {
            if (bestScore[start] == Double.NEGATIVE_INFINITY) {
                continue
            }

            for (end in start + 1..source.length) {
                val candidate = source.substring(start, end)
                val tokenId = tokenToId[candidate] ?: continue
                val tokenScore = tokenScores[candidate] ?: continue
                val nextScore = bestScore[start] + tokenScore
                if (nextScore > bestScore[end]) {
                    bestScore[end] = nextScore
                    bestPrevious[end] = start
                    bestTokenId[end] = tokenId
                }
            }
        }

        if (bestPrevious[source.length] == -1) {
            return fallbackSegment(source, unkTokenId)
        }

        val encoded = mutableListOf<Int>()
        var index = source.length
        while (index > 0) {
            val tokenId = bestTokenId[index]
            val previous = bestPrevious[index]
            if (tokenId == -1 || previous == -1) {
                return fallbackSegment(source, unkTokenId)
            }
            encoded.add(tokenId)
            index = previous
        }
        encoded.reverse()
        return encoded
    }

    private fun fallbackSegment(source: String, unkTokenId: Int): List<Int> {
        val encoded = mutableListOf<Int>()
        var cursor = 0
        while (cursor < source.length) {
            var matched = false
            for (end in source.length downTo cursor + 1) {
                val candidate = source.substring(cursor, end)
                val tokenId = tokenToId[candidate]
                if (tokenId != null) {
                    encoded.add(tokenId)
                    cursor = end
                    matched = true
                    break
                }
            }

            if (!matched) {
                val nextChar = source[cursor].toString()
                encoded.add(tokenToId[nextChar] ?: unkTokenId)
                cursor += 1
            }
        }
        return encoded
    }

    private fun resolveFallbackTokenId(token: String, unkTokenId: Int): Int {
        return ((token.lowercase().hashCode().toLong() and 0x7fffffff) % 30000).toInt() + unkTokenId
    }

    private fun runEncoder(
        inputIds: LongArray,
        attentionMask: LongArray,
    ): EncoderHiddenState? {
        val env = environment ?: return null
        val currentEncoderSession = encoderSession ?: return null
        return try {
            val idsTensor = OnnxTensor.createTensor(
                env,
                LongBuffer.wrap(inputIds),
                longArrayOf(1, inputIds.size.toLong()),
            )
            val maskTensor = OnnxTensor.createTensor(
                env,
                LongBuffer.wrap(attentionMask),
                longArrayOf(1, attentionMask.size.toLong()),
            )
            idsTensor.use { ids ->
                maskTensor.use { mask ->
                    val feed = linkedMapOf<String, OnnxTensor>()
                    feed["input_ids"] = ids
                    feed["attention_mask"] = mask
                    currentEncoderSession.run(feed).use { results ->
                        val hidden = results[0] as? OnnxTensor ?: return null
                        val shape = hidden.info.shape
                        val flat = FloatArray(hidden.floatBuffer.remaining())
                        hidden.floatBuffer.get(flat)
                        EncoderHiddenState(
                            values = flat,
                            shape = shape,
                        )
                    }
                }
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun runDecoderStep(
        decoderIds: LongArray,
        attentionMask: LongArray,
        encoderHiddenState: EncoderHiddenState,
        generatedIds: List<Int>,
        eosTokenId: Int,
        minGeneratedTokens: Int,
        unkTokenId: Int,
    ): Int? {
        val env = environment ?: return null
        val currentDecoderSession = decoderSession ?: return null
        return try {
            val decoderTensor = OnnxTensor.createTensor(
                env,
                LongBuffer.wrap(decoderIds),
                longArrayOf(1, decoderIds.size.toLong()),
            )
            val maskTensor = OnnxTensor.createTensor(
                env,
                LongBuffer.wrap(attentionMask),
                longArrayOf(1, attentionMask.size.toLong()),
            )
            val hiddenTensor = OnnxTensor.createTensor(
                env,
                FloatBuffer.wrap(encoderHiddenState.values),
                encoderHiddenState.shape,
            )

            decoderTensor.use { decoderInput ->
                maskTensor.use { encoderMask ->
                    hiddenTensor.use { encoderHidden ->
                        val feed = linkedMapOf<String, OnnxTensor>()
                        feed["encoder_attention_mask"] = encoderMask
                        feed["input_ids"] = decoderInput
                        feed["encoder_hidden_states"] = encoderHidden
                        currentDecoderSession.run(feed).use { results ->
                            val logits = results[0] as? OnnxTensor ?: return null
                            val shape = logits.info.shape
                            val vocabSize = shape.lastOrNull()?.toInt() ?: return null
                            val values = FloatArray(logits.floatBuffer.remaining())
                            logits.floatBuffer.get(values)
                            val offset = maxOf(0, values.size - vocabSize)
                            selectNextToken(
                                values = values,
                                offset = offset,
                                vocabSize = vocabSize,
                                generatedIds = generatedIds,
                                eosTokenId = eosTokenId,
                                minGeneratedTokens = minGeneratedTokens,
                                unkTokenId = unkTokenId,
                            )
                        }
                    }
                }
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun runDecoderPreview(
        decoderIds: LongArray,
        attentionMask: LongArray,
        encoderHiddenState: EncoderHiddenState,
    ): Pair<List<String>, List<String>> {
        val env = environment ?: throw IllegalStateException("ONNX environment unavailable.")
        val currentDecoderSession = decoderSession ?: throw IllegalStateException("Decoder session unavailable.")

        val decoderTensor = OnnxTensor.createTensor(
            env,
            LongBuffer.wrap(decoderIds),
            longArrayOf(1, decoderIds.size.toLong()),
        )
        val maskTensor = OnnxTensor.createTensor(
            env,
            LongBuffer.wrap(attentionMask),
            longArrayOf(1, attentionMask.size.toLong()),
        )
        val hiddenTensor = OnnxTensor.createTensor(
            env,
            FloatBuffer.wrap(encoderHiddenState.values),
            encoderHiddenState.shape,
        )

        decoderTensor.use { decoderInput ->
            maskTensor.use { encoderMask ->
                hiddenTensor.use { encoderHidden ->
                    val feed = linkedMapOf<String, OnnxTensor>()
                    feed["encoder_attention_mask"] = encoderMask
                    feed["input_ids"] = decoderInput
                    feed["encoder_hidden_states"] = encoderHidden
                    currentDecoderSession.run(feed).use { results ->
                        val shapes = results.mapIndexed { index, value ->
                            val shape = if (value is OnnxTensor) {
                                value.info.shape.joinToString(prefix = "[", postfix = "]")
                            } else {
                                "[unknown]"
                            }
                            val name = if (index == 0) "logits" else "output_$index"
                            "$name=$shape"
                        }
                        val sample = results.flatMap { extractValueSample(it) }.take(12)
                        return shapes to sample
                    }
                }
            }
        }
    }

    private fun decodeTokenIds(
        tokenIds: List<Int>,
        bosTokenId: Int,
        eosTokenId: Int,
        padTokenId: Int,
        unkTokenId: Int,
    ): String {
        if (idToToken.isEmpty()) {
            return ""
        }

        val builder = StringBuilder()
        for (tokenId in tokenIds) {
            if (tokenId == bosTokenId || tokenId == eosTokenId || tokenId == padTokenId) {
                continue
            }
            if (tokenId == unkTokenId) {
                continue
            }
            val token = idToToken[tokenId] ?: continue
            if (token.startsWith("<extra_id_") || token.startsWith("<")) {
                continue
            }
            builder.append(token)
        }

        return cleanupGeneratedSummary(
            builder.toString()
            .replace("▁", " ")
            .replace(Regex("\\s+([,.!?;:])"), "$1")
            .replace(Regex("\\s+"), " ")
            .trim()
        )
    }

    private fun fallbackSummary(title: String?, body: String): String {
        val normalized = body.replace(Regex("\\s+"), " ").trim()
        if (normalized.isEmpty()) {
            return "This note is still empty."
        }
        val sentences = normalized
            .split(Regex("(?<=[.!?])\\s+"))
            .map { it.trim() }
            .filter { it.isNotEmpty() }
        if (sentences.isEmpty()) {
            return normalized
        }

        val chosen = mutableListOf<String>()
        for (sentence in sentences) {
            if (title != null && title.trim().isNotEmpty()) {
                val titleTerms = title.lowercase().split(Regex("[^a-z0-9]+")).filter { it.length > 2 }.toSet()
                val sentenceTerms = sentence.lowercase().split(Regex("[^a-z0-9]+")).filter { it.length > 2 }.toSet()
                if (titleTerms.isNotEmpty() && sentenceTerms.isNotEmpty()) {
                    val overlap = titleTerms.intersect(sentenceTerms).size
                    if (overlap > 0 && overlap == sentenceTerms.size) {
                        continue
                    }
                }
            }

            chosen.add(sentence)
            if (chosen.size == 2) {
                break
            }
        }

        val summary = if (chosen.isNotEmpty()) {
            chosen.joinToString(" ")
        } else {
            sentences.first()
        }
        return anchorToTitle(title, cleanupGeneratedSummary(summary))
    }

    private fun cleanupGeneratedSummary(input: String): String {
        var output = input.trim()
        output = output.replace(Regex("^\\s*(summary|summarize)\\s*:\\s*", RegexOption.IGNORE_CASE), "")
        output = output.replace(Regex("\\s+"), " ").trim()
        output = output.replace(Regex("^[,:;\\-\\s]+"), "")
        output = output.replace(Regex("\\s*[:;,-]\\s*$"), "")

        val sentences = output
            .split(Regex("(?<=[.!?])\\s+"))
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .distinct()

        output = when {
            sentences.size >= 2 -> sentences.take(2).joinToString(" ")
            sentences.isNotEmpty() -> sentences.first()
            else -> output
        }

        if (output.length > 280) {
            output = output.substring(0, 280).trim()
            output = output.replace(Regex("\\s+[\\p{L}\\p{N}]*$"), "").trim()
        }

        if (!Regex("[.!?]$").containsMatchIn(output) && output.isNotBlank()) {
            output += "."
        }

        return output.trim()
    }

    private fun anchorToTitle(title: String?, summary: String): String {
        val cleanedTitle = title?.replace(Regex("\\s+"), " ")?.trim().orEmpty()
        if (cleanedTitle.isBlank() || summary.isBlank()) {
            return summary
        }
        if (summary.startsWith(cleanedTitle, ignoreCase = true)) {
            return summary
        }
        if (!Regex("^(it|this note|this|these|they|there)\\b", RegexOption.IGNORE_CASE).containsMatchIn(summary)) {
            return summary
        }

        val normalizedTitle = cleanedTitle.replaceFirstChar {
            if (it.isLowerCase()) it.titlecase() else it.toString()
        }
        return summary.replaceFirst(
            Regex("^(it|this note|this|these|they)\\b", RegexOption.IGNORE_CASE),
            normalizedTitle,
        ).trim()
    }

    private fun argmax(values: FloatArray, offset: Int, size: Int): Int {
        var bestIndex = 0
        var bestValue = Float.NEGATIVE_INFINITY
        for (index in 0 until min(size, values.size - offset)) {
            val value = values[offset + index]
            if (value > bestValue) {
                bestValue = value
                bestIndex = index
            }
        }
        return bestIndex
    }

    private fun selectNextToken(
        values: FloatArray,
        offset: Int,
        vocabSize: Int,
        generatedIds: List<Int>,
        eosTokenId: Int,
        minGeneratedTokens: Int,
        unkTokenId: Int,
    ): Int {
        val adjusted = FloatArray(vocabSize)
        for (index in 0 until vocabSize) {
            adjusted[index] = values[offset + index]
        }

        if (generatedIds.size <= minGeneratedTokens) {
            adjusted[eosTokenId] = Float.NEGATIVE_INFINITY
        }
        adjusted[unkTokenId] = Float.NEGATIVE_INFINITY

        val seenCounts = generatedIds.groupingBy { it }.eachCount()
        for ((tokenId, count) in seenCounts) {
            if (tokenId in 0 until vocabSize) {
                adjusted[tokenId] -= 0.6f * count
            }
        }

        val repeatPenaltyIds = recentRepeatCandidates(generatedIds)
        for (tokenId in repeatPenaltyIds) {
            if (tokenId in 0 until vocabSize) {
                adjusted[tokenId] -= 2.5f
            }
        }

        val blockedTokenId = blockedNGramToken(generatedIds, 3)
        if (blockedTokenId != null && blockedTokenId in 0 until vocabSize) {
            adjusted[blockedTokenId] = Float.NEGATIVE_INFINITY
        }

        return argmax(adjusted, 0, adjusted.size)
    }

    private fun recentRepeatCandidates(generatedIds: List<Int>): Set<Int> {
        val blocked = mutableSetOf<Int>()
        if (generatedIds.size >= 1) {
            blocked.add(generatedIds.last())
        }
        if (generatedIds.size >= 2 && generatedIds.last() == generatedIds[generatedIds.lastIndex - 1]) {
            blocked.add(generatedIds.last())
        }
        return blocked
    }

    private fun blockedNGramToken(generatedIds: List<Int>, ngramSize: Int): Int? {
        if (ngramSize < 2 || generatedIds.size < ngramSize - 1) {
            return null
        }

        val prefixLength = ngramSize - 1
        val currentPrefix = generatedIds.takeLast(prefixLength)
        for (index in 0..generatedIds.size - ngramSize) {
            val window = generatedIds.subList(index, index + ngramSize)
            if (window.take(prefixLength) == currentPrefix) {
                return window.last()
            }
        }
        return null
    }

    private fun extractValueSample(value: Any?): List<String> {
        val tensor = value as? OnnxTensor ?: return emptyList()
        return try {
            flattenSample(tensor.value).take(12)
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun flattenSample(value: Any?): List<String> {
        return when (value) {
            null -> emptyList()
            is FloatArray -> value.map { it.toString() }
            is LongArray -> value.map { it.toString() }
            is IntArray -> value.map { it.toString() }
            is DoubleArray -> value.map { it.toString() }
            is Array<*> -> value.flatMap { flattenSample(it) }
            is Iterable<*> -> value.flatMap { flattenSample(it) }
            else -> listOf(value.toString())
        }
    }

    private fun closeSummarySession() {
        try {
            encoderSession?.close()
        } catch (_: Exception) {
        }
        try {
            decoderSession?.close()
        } catch (_: Exception) {
        } finally {
            encoderSession = null
            decoderSession = null
            encoderModelPath = null
            decoderModelPath = null
            summaryInputNames = emptyList()
            summaryOutputNames = emptyList()
            summaryMaxSequenceLength = null
            tokenizerPath = null
            tokenToId = emptyMap()
            tokenScores = emptyMap()
            idToToken = emptyMap()
        }
    }

    private data class EncoderHiddenState(
        val values: FloatArray,
        val shape: LongArray,
    )
}
