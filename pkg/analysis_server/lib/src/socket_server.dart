// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/protocol/protocol.dart';
import 'package:analysis_server/protocol/protocol_generated.dart';
import 'package:analysis_server/src/analysis_server.dart';
import 'package:analysis_server/src/channel/channel.dart';
import 'package:analysis_server/src/server/diagnostic_server.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/instrumentation/instrumentation.dart';
import 'package:analyzer/src/generated/sdk.dart';
import 'package:analyzer/src/plugin/resolver_provider.dart';
import 'package:analyzer/src/source/pub_package_map_provider.dart';

/**
 * Instances of the class [SocketServer] implement the common parts of
 * http-based and stdio-based analysis servers.  The primary responsibility of
 * the SocketServer is to manage the lifetime of the AnalysisServer and to
 * encode and decode the JSON messages exchanged with the client.
 */
class SocketServer {
  final AnalysisServerOptions analysisServerOptions;

  /**
   * The function used to create a new SDK using the default SDK.
   */
  final DartSdkManager sdkManager;

  final DartSdk defaultSdk;
  final InstrumentationService instrumentationService;
  final DiagnosticServer diagnosticServer;
  final ResolverProvider fileResolverProvider;
  final ResolverProvider packageResolverProvider;

  /**
   * The analysis server that was created when a client established a
   * connection, or `null` if no such connection has yet been established.
   */
  AnalysisServer analysisServer;

  SocketServer(
      this.analysisServerOptions,
      this.sdkManager,
      this.defaultSdk,
      this.instrumentationService,
      this.diagnosticServer,
      this.fileResolverProvider,
      this.packageResolverProvider);

  /**
   * Create an analysis server which will communicate with the client using the
   * given serverChannel.
   */
  void createAnalysisServer(ServerCommunicationChannel serverChannel) {
    if (analysisServer != null) {
      RequestError error = new RequestError(
          RequestErrorCode.SERVER_ALREADY_STARTED, "Server already started");
      serverChannel.sendResponse(new Response('', error: error));
      serverChannel.listen((Request request) {
        serverChannel.sendResponse(new Response(request.id, error: error));
      });
      return;
    }

    PhysicalResourceProvider resourceProvider;
    if (analysisServerOptions.fileReadMode == 'as-is') {
      resourceProvider = new PhysicalResourceProvider(null,
          stateLocation: analysisServerOptions.cacheFolder);
    } else if (analysisServerOptions.fileReadMode == 'normalize-eol-always') {
      resourceProvider = new PhysicalResourceProvider(
          PhysicalResourceProvider.NORMALIZE_EOL_ALWAYS,
          stateLocation: analysisServerOptions.cacheFolder);
    } else {
      throw new Exception(
          'File read mode was set to the unknown mode: $analysisServerOptions.fileReadMode');
    }

    analysisServer = new AnalysisServer(
        serverChannel,
        resourceProvider,
        new PubPackageMapProvider(resourceProvider, defaultSdk),
        analysisServerOptions,
        sdkManager,
        instrumentationService,
        diagnosticServer: diagnosticServer,
        fileResolverProvider: fileResolverProvider,
        packageResolverProvider: packageResolverProvider);
  }
}
