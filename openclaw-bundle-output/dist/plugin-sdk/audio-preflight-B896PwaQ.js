import "./github-copilot-token-C4Aasre6.js";
import "./channel-config-helpers-CCwuHoQg.js";
import { Ei as resolveMediaAttachmentLocalRoots, Mi as isAudioAttachment, Si as runAudioTranscription, Ti as normalizeMediaAttachments } from "./thread-bindings-CDWYLtZg.js";
import "./paths-WR8OhEmw.js";
import "./logger-BMJylom9.js";
import "./tmp-openclaw-dir-DEAexD45.js";
import { d as logVerbose, m as shouldLogVerbose } from "./subsystem-BMFHCK0B.js";
import "./utils-DqTdif_t.js";
import "./fetch-DL21dquM.js";
import "./exec-aRKcm84F.js";
import "./thinking-D7ZEZ42s.js";
import "./query-expansion-DDyF7AkT.js";
import "./logger-DsMMlJaT.js";
import "./zod-schema.core-CtLVNGPW.js";
import "./redact-CbfjPwKV.js";
import "./http-registry-BnsTVTl7.js";
import "./pairing-token-DNSESXf3.js";
import "./ssrf-BC5-OCfy.js";
import "./fetch-guard-C4qWqp_z.js";
import "./registry-B_tf98QY.js";
import "./http-body-CdacFz6y.js";
//#region src/media-understanding/audio-preflight.ts
/**
* Transcribes the first audio attachment BEFORE mention checking.
* This allows voice notes to be processed in group chats with requireMention: true.
* Returns the transcript or undefined if transcription fails or no audio is found.
*/
async function transcribeFirstAudio(params) {
	const { ctx, cfg } = params;
	const audioConfig = cfg.tools?.media?.audio;
	if (!audioConfig || audioConfig.enabled === false) return;
	const attachments = normalizeMediaAttachments(ctx);
	if (!attachments || attachments.length === 0) return;
	const firstAudio = attachments.find((att) => att && isAudioAttachment(att) && !att.alreadyTranscribed);
	if (!firstAudio) return;
	if (shouldLogVerbose()) logVerbose(`audio-preflight: transcribing attachment ${firstAudio.index} for mention check`);
	try {
		const { transcript } = await runAudioTranscription({
			ctx,
			cfg,
			attachments,
			agentDir: params.agentDir,
			providers: params.providers,
			activeModel: params.activeModel,
			localPathRoots: resolveMediaAttachmentLocalRoots({
				cfg,
				ctx
			})
		});
		if (!transcript) return;
		firstAudio.alreadyTranscribed = true;
		if (shouldLogVerbose()) logVerbose(`audio-preflight: transcribed ${transcript.length} chars from attachment ${firstAudio.index}`);
		return transcript;
	} catch (err) {
		if (shouldLogVerbose()) logVerbose(`audio-preflight: transcription failed: ${String(err)}`);
		return;
	}
}
//#endregion
export { transcribeFirstAudio };
