/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on TraceSection.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/

import hiTraceMeter from '@ohos.hiTraceMeter'

export class TraceSection {

  static taskId: number = 0;

  private static cropSectionName(sectionName: string): string {
    return sectionName.length < 124 ? sectionName : sectionName.substring(0, 124) + "...";
  }

  /**
   * Wraps Trace.beginSection to ensure that the line length stays below 127 code units.
   *
   * @param sectionName The string to display as the section name in the trace.
   */
  public static begin(sectionName: string): number {
    TraceSection.taskId++;
    hiTraceMeter.startTrace(TraceSection.cropSectionName(sectionName), TraceSection.taskId);
    return TraceSection.taskId;
  }

  /** Wraps Trace.endSection. */
  public static end(sectionName: string): void {
    hiTraceMeter.finishTrace(TraceSection.cropSectionName(sectionName), TraceSection.taskId);
  }

  public static endWithId(sectionName: string, id: number): void {
    hiTraceMeter.finishTrace(TraceSection.cropSectionName(sectionName), id);
  }
}
