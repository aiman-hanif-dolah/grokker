import 'package:equatable/equatable.dart';

class AppError extends Equatable implements Exception {
  const AppError({
    required this.title,
    required this.message,
    required this.suggestedFix,
    this.technicalDetails,
  });

  final String title;
  final String message;
  final String suggestedFix;
  final String? technicalDetails;

  @override
  List<Object?> get props => [title, message, suggestedFix, technicalDetails];
}

class GrokCliNotFoundError extends AppError {
  const GrokCliNotFoundError({String? technicalDetails})
    : super(
        title: 'Grok CLI not found.',
        message:
            'Grokker could not find the Grok Build CLI on your PATH or configured command path.',
        suggestedFix:
            'Install Grok Build CLI, then run grok /login in your terminal and restart Grokker.',
        technicalDetails: technicalDetails,
      );
}

class GrokCliNotAuthenticatedError extends AppError {
  const GrokCliNotAuthenticatedError({String? technicalDetails})
    : super(
        title: 'Grok CLI not authenticated.',
        message:
            'Grok Build CLI appears installed but is not authenticated for this machine.',
        suggestedFix: 'Run grok /login in your terminal, then restart Grokker.',
        technicalDetails: technicalDetails,
      );
}

class AcpInitializeFailedError extends AppError {
  const AcpInitializeFailedError({String? technicalDetails})
    : super(
        title: 'ACP initialize failed.',
        message:
            'Grokker could not initialize the ACP connection with Grok Build CLI.',
        suggestedFix:
            'Check that grok agent stdio works in your terminal, then restart the Grok process.',
        technicalDetails: technicalDetails,
      );
}

class AcpSessionCreationFailedError extends AppError {
  const AcpSessionCreationFailedError({String? technicalDetails})
    : super(
        title: 'ACP session creation failed.',
        message: 'Grokker could not create a new ACP session.',
        suggestedFix:
            'Restart the Grok process and try creating a new session.',
        technicalDetails: technicalDetails,
      );
}

class PromptSendFailedError extends AppError {
  const PromptSendFailedError({String? technicalDetails})
    : super(
        title: 'Prompt send failed.',
        message: 'Your message could not be sent to Grok Build CLI.',
        suggestedFix:
            'Check the Grok process status and try again. Restart Grok if needed.',
        technicalDetails: technicalDetails,
      );
}

class ProcessExitedError extends AppError {
  const ProcessExitedError({String? technicalDetails})
    : super(
        title: 'Grok process exited unexpectedly.',
        message:
            'The Grok Build CLI process stopped while Grokker was running.',
        suggestedFix: 'Restart the Grok process from diagnostics or settings.',
        technicalDetails: technicalDetails,
      );
}

class ModelUnavailableError extends AppError {
  const ModelUnavailableError({String? technicalDetails})
    : super(
        title: 'Selected model unavailable.',
        message:
            'The selected model is not currently exposed by your Grok Build CLI account or this ACP session.',
        suggestedFix:
            'Choose a different model or verify your SuperGrok subscription capabilities.',
        technicalDetails: technicalDetails,
      );
}

class AttachmentMissingError extends AppError {
  const AttachmentMissingError({String? technicalDetails})
    : super(
        title: 'Attachment file missing.',
        message: 'One or more attached files could not be found on disk.',
        suggestedFix: 'Remove missing attachments and re-attach the files.',
        technicalDetails: technicalDetails,
      );
}

class ResponseTimeoutError extends AppError {
  const ResponseTimeoutError({String? technicalDetails})
    : super(
        title: 'Timeout waiting for response.',
        message: 'Grok Build CLI did not respond within the expected time.',
        suggestedFix:
            'Try again or cancel the current generation. Restart Grok if this persists.',
        technicalDetails: technicalDetails,
      );
}
