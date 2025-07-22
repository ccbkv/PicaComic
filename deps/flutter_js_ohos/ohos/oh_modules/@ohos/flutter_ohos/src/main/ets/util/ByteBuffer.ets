/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*/

import util from '@ohos.util'
import StringUtils from './StringUtils'

/**
 * A byte buffer.
 *
 * Supports the following data types:
 * - Bool
 * - Int (8, 16, 32, 64)
 * - Uint (8, 16, 32, 64)
 * - BigInt (64)
 * - String (utf8, utf16, and delimited)
 * - TypedArray
 *
 */
export class ByteBuffer {
  /**
   * Creates a byte buffer.
   * @param source The data source.
   * @param byteOffset The byte offset.
   * @param byteLength The byte length.
   * @returns A byte buffer.
   */
  static from(source: ArrayBuffer, byteOffset?: number, byteLength?: number): ByteBuffer {
    const byteBuffer = new ByteBuffer()
    byteBuffer.dataView = byteLength === undefined ? new DataView(source, byteOffset) :
      new DataView(source, byteOffset, Math.min(source.byteLength, byteLength))
    byteBuffer.mByteOffset = byteBuffer.dataView.byteOffset
    return byteBuffer
  }

  /**
   * The dataView.
   */
  private dataView?: DataView
  /**
   * The byte offset.
   */
  mByteOffset: number = 0

  /**
   * The byte offset.
   * @returns The byte offset.
   */
  get byteOffset(): number {
    return this.mByteOffset
  }

  /**
   * The byte offset.
   * @returns The byte offset.
   */
  get byteLength(): number {
    return this.dataView?.byteLength ?? 0
  }

  /**
   * The number of remaining bytes.
   * @returns The number of bytes remaining.
   */
  get bytesRemaining(): number {
    return this.dataView ? this.dataView.byteLength - this.mByteOffset : 0;
  }

  hasRemaining(): boolean {
    return this.dataView != undefined && this.mByteOffset < this.dataView.byteLength;
  }

  get buffer(): ArrayBuffer {
    return this.dataView!.buffer.slice(0, this.mByteOffset)
  }

  /**
   * Skips the byte offset.
   * @param byteLength The byte length.
   */
  skip(byteLength: number): void {
    this.mByteOffset += byteLength
  }

  /**
   * Resets the byte offset.
   */
  reset(): void {
    this.mByteOffset = this.dataView?.byteOffset ?? 0
  }

  /**
   * Clears the byte buffer.
   */
  clear(): void {
    this.getUint8Array(0).fill(0)
  }

  /**
   * check buffer capacity.
   */
  checkWriteCapacity(slen: number): void {
    if (this.mByteOffset + slen > this.dataView!.byteLength) {
      let newCapacity = this.dataView!.byteLength + (this.dataView!.byteLength >> 1);
      if (newCapacity < this.dataView!.byteLength + slen + 512) {
        newCapacity = this.dataView!.byteLength + slen + 512;
      }
      let newBuffer = new ArrayBuffer(newCapacity);
      let newDataView = new DataView(newBuffer);
      let oldUint8Array = new Uint8Array(this.dataView!.buffer);
      let newUint8Array = new Uint8Array(newBuffer);
      newUint8Array.set(oldUint8Array);
      this.dataView = newDataView;
    }
  }

  /**
   * Gets a boolean.
   * @param byteOffset The byte offset.
   */
  getBool(byteOffset: number): boolean {
    return this.getInt8(byteOffset) !== 0
  }

  /**
   * Reads the next boolean.
   */
  readBool(): boolean {
    return this.getInt8(this.mByteOffset++) !== 0
  }

  /**
   * Sets a boolean.
   * @param byteOffset The byte offset.
   * @param value The value.
   */
  setBool(byteOffset: number, value: boolean): void {
    this.dataView?.setInt8(byteOffset, value ? 1 : 0)
  }

  /**
   * Writes the next boolean.
   * @param value The value.
   */
  writeBool(value: boolean): void {
    this.checkWriteCapacity(1)
    this.setInt8(this.mByteOffset++, value ? 1 : 0)
  }

  /**
   * Gets an signed byte.
   * @param byteOffset The byte offset.
   * @returns The value.
   */
  getInt8(byteOffset: number): number {
    return this.dataView?.getInt8(byteOffset) || 0
  }

  /**
   * Reads the next signed byte.
   * @returns The value.
   */
  readInt8(): number {
    return this.getInt8(this.mByteOffset++)
  }

  /**
   * Sets a signed byte.
   * @param byteOffset The byte offset.
   * @param value The value.
   */
  setInt8(byteOffset: number, value: number): void {
    this.dataView?.setInt8(byteOffset, value)
  }

  /**
   * Writes the next signed byte.
   * @param value The value.
   */
  writeInt8(value: number): void {
    this.checkWriteCapacity(1)
    this.setInt8(this.mByteOffset++, value)
  }

  /**
   * Gets an unsigned byte.
   * @param byteOffset The byte offset.
   * @returns The value.
   */
  getUint8(byteOffset: number): number {
    return this.dataView?.getUint8(byteOffset) || 0
  }

  /**
   * Reads the next unsigned byte.
   * @returns The value.
   */
  readUint8(): number {
    return this.getUint8(this.mByteOffset++)
  }

  /**
   * Sets an unsigned byte.
   * @param byteOffset The byte offset.
   * @param value The value.
   */
  setUint8(byteOffset: number, value: number): void {
    this.dataView?.setUint8(byteOffset, value)
  }

  /**
   * Writes the next signed byte.
   * @param value The value.
   */
  writeUint8(value: number): void {
    this.checkWriteCapacity(1)
    this.setUint8(this.mByteOffset++, value)
  }

  /**
   * Gets an signed short.
   * @param byteOffset The byte offset.
   * @param littleEndian If the value is little endian.
   * @returns The value.
   */
  getInt16(byteOffset: number, littleEndian?: boolean): number {
    return this.dataView?.getInt16(byteOffset, littleEndian) || 0
  }

  /**
   * Reads the next signed short.
   * @param littleEndian If the value is little endian.
   * @returns The value.
   */
  readInt16(littleEndian?: boolean): number {
    const value = this.getInt16(this.mByteOffset, littleEndian)
    this.mByteOffset += 2
    return value
  }

  /**
   * Sets a signed short.
   * @param byteOffset The byte offset.
   * @param value The value.
   * @param littleEndian If the value is little endian.
   */
  setInt16(byteOffset: number, value: number, littleEndian?: boolean): void {
    this.dataView?.setInt16(byteOffset, value, littleEndian)
  }

  /**
   * Writes the next signed short.
   * @param value The value.
   * @param littleEndian If the value is little endian.
   */
  writeInt16(value: number, littleEndian?: boolean): void {
    this.checkWriteCapacity(2)
    this.setInt16(this.mByteOffset, value, littleEndian)
    this.mByteOffset += 2
  }

  /**
   * Gets an unsigned short.
   * @param byteOffset The byte offset.
   * @param littleEndian If the value is little endian.
   * @returns The value.
   */
  getUint16(byteOffset: number, littleEndian?: boolean): number {
    return this.dataView?.getUint16(byteOffset, littleEndian) || 0
  }

  /**
   * Reads the next unsigned short.
   * @param littleEndian If the value is little endian.
   * @returns The value.
   */
  readUint16(littleEndian?: boolean): number {
    const value = this.getUint16(this.mByteOffset, littleEndian)
    this.mByteOffset += 2
    return value
  }

  /**
   * Sets an unsigned short.
   * @param byteOffset The byte offset.
   * @param value The value.
   * @param littleEndian If the value is little endian.
   */
  setUint16(byteOffset: number, value: number, littleEndian?: boolean): void {
    this.dataView?.setUint16(byteOffset, value, littleEndian)
  }

  /**
   * Writes the next signed short.
   * @param value The value.
   * @param littleEndian If the value is little endian.
   */
  writeUint16(value: number, littleEndian?: boolean): void {
    this.checkWriteCapacity(2)
    this.setUint16(this.mByteOffset, value, littleEndian)
    this.mByteOffset += 2
  }

  /**
   * Gets an signed integer.
   * @param byteOffset The byte offset.
   * @param littleEndian If the value is little endian.
   * @returns The value.
   */
  getInt32(byteOffset: number, littleEndian?: boolean): number {
    return this.dataView?.getInt32(byteOffset, littleEndian) ?? 0
  }

  /**
   * Reads the next signed integer.
   * @param littleEndian If the value is little endian.
   * @returns The value.
   */
  readInt32(littleEndian?: boolean): number {
    const value = this.getInt32(this.mByteOffset, littleEndian)
    this.mByteOffset += 4
    return value
  }

  /**
   * Sets a signed integer.
   * @param byteOffset The byte offset.
   * @param value The value.
   * @param littleEndian If the value is little endian.
   */
  setInt32(byteOffset: number, value: number, littleEndian?: boolean): void {
    this.dataView?.setInt32(byteOffset, value, littleEndian)
  }

  /**
   * Writes the next signed integer.
   * @param value The value.
   * @param littleEndian If the value is little endian.
   */
  writeInt32(value: number, littleEndian?: boolean): void {
    this.checkWriteCapacity(4)
    this.setInt32(this.mByteOffset, value, littleEndian)
    this.mByteOffset += 4
  }

  /**
   * Gets an unsigned integer.
   * @param byteOffset The byte offset.
   * @param littleEndian If the value is little endian.
   * @returns The value.
   */
  getUint32(byteOffset: number, littleEndian?: boolean): number {
    return this.dataView?.getUint32(byteOffset, littleEndian) ?? 0
  }

  /**
   * Reads the next unsigned integer.
   * @param littleEndian If the value is little endian.
   * @returns The value.
   */
  readUint32(littleEndian?: boolean): number {
    const value = this.getUint32(this.mByteOffset, littleEndian)
    this.mByteOffset += 4
    return value
  }

  /**
   * Sets an unsigned integer.
   * @param byteOffset The byte offset.
   * @param value The value.
   * @param littleEndian If the value is little endian.
   */
  setUint32(byteOffset: number, value: number, littleEndian?: boolean): void {
    this.dataView?.setUint32(byteOffset, value, littleEndian)
  }

  /**
   * Writes the next signed integer.
   * @param value The value.
   * @param littleEndian If the value is little endian.
   */
  writeUint32(value: number, littleEndian?: boolean): void {
    this.checkWriteCapacity(4)
    this.setUint32(this.mByteOffset, value, littleEndian)
    this.mByteOffset += 4
  }

  /**
   * Gets a float.
   * @param byteOffset The byte offset.
   * @param littleEndian If the value is little endian.
   * @returns The value.
   */
  getFloat32(byteOffset: number, littleEndian?: boolean): number {
    return this.dataView?.getFloat32(byteOffset, littleEndian) ?? 0
  }

  /**
   * Reads the next float.
   * @param littleEndian If the value is little endian.
   * @returns The value.
   */
  readFloat32(littleEndian?: boolean): number {
    const value = this.getFloat32(this.mByteOffset, littleEndian)
    this.mByteOffset += 4
    return value
  }

  /**
   * Sets a float.
   * @param byteOffset The byte offset.
   * @param value The value.
   * @param littleEndian If the value is little endian.
   */
  setFloat32(byteOffset: number, value: number, littleEndian?: boolean): void {
    this.dataView?.setFloat32(byteOffset, value, littleEndian)
  }

  /**
   * Writes the next float.
   * @param value The value.
   * @param littleEndian If the value is little endian.
   */
  writeFloat32(value: number, littleEndian?: boolean): void {
    this.checkWriteCapacity(4)
    this.setFloat32(this.mByteOffset, value, littleEndian)
    this.mByteOffset += 4
  }

  /**
   * Gets a double.
   * @param byteOffset The byte offset.
   * @param littleEndian If the value is little endian.
   * @returns The value.
   */
  getFloat64(byteOffset: number, littleEndian?: boolean): number {
    return this.dataView?.getFloat64(byteOffset, littleEndian) ?? 0
  }

  /**
   * Reads the next double.
   * @param littleEndian If the value is little endian.
   * @returns The value.
   */
  readFloat64(littleEndian?: boolean): number {
    const value = this.getFloat64(this.mByteOffset, littleEndian)
    this.mByteOffset += 8
    return value
  }

  /**
   * Sets a double.
   * @param byteOffset The byte offset.
   * @param value The value.
   * @param littleEndian If the value is little endian.
   */
  setFloat64(byteOffset: number, value: number, littleEndian?: boolean): void {
    this.dataView?.setFloat64(byteOffset, value, littleEndian)
  }

  /**
   * Writes the next double.
   * @param value The value.
   * @param littleEndian If the value is little endian.
   */
  writeFloat64(value: number, littleEndian?: boolean): void {
    this.checkWriteCapacity(8)
    this.setFloat64(this.mByteOffset, value, littleEndian)
    this.mByteOffset += 8
  }

  /**
   * Gets an signed long.
   * @param byteOffset The byte offset.
   * @param littleEndian If the value is little endian.
   * @returns The value.
   */
  getBigInt64(byteOffset: number, littleEndian?: boolean): bigint {
    return this.dataView?.getBigInt64(byteOffset, littleEndian) ?? BigInt(0)
  }

  /**
   * Reads the next signed long.
   * @param littleEndian If the value is little endian.
   * @returns The value.
   */
  readBigInt64(littleEndian?: boolean): bigint {
    const value = this.getBigInt64(this.mByteOffset, littleEndian)
    this.mByteOffset += 8
    return value
  }

  /**
   * Sets a signed long.
   * @param byteOffset The byte offset.
   * @param value The value.
   * @param littleEndian If the value is little endian.
   */
  setBigInt64(byteOffset: number, value: bigint, littleEndian?: boolean): void {
    this.dataView?.setBigInt64(byteOffset, value, littleEndian)
  }

  /**
   * Writes the next signed long.
   * @param value The value.
   * @param littleEndian If the value is little endian.
   */
  writeBigInt64(value: bigint, littleEndian?: boolean): void {
    this.checkWriteCapacity(8)
    this.setBigInt64(this.mByteOffset, value, littleEndian)
    this.mByteOffset += 8
  }

  /**
   * Gets an unsigned long.
   * @param byteOffset The byte offset.
   * @param littleEndian If the value is little endian.
   * @returns The value.
   */
  getBigUint64(byteOffset: number, littleEndian?: boolean): bigint {
    return this.dataView?.getBigUint64(byteOffset, littleEndian) ?? BigInt(0)
  }

  /**
   * Reads the next unsigned long.
   * @param littleEndian If the value is little endian.
   * @returns The value.
   */
  readBigUint64(littleEndian?: boolean): bigint {
    const value = this.getBigUint64(this.mByteOffset, littleEndian)
    this.mByteOffset += 8
    return value
  }

  /**
   * Sets an unsigned long.
   * @param byteOffset The byte offset.
   * @param value The value.
   * @param littleEndian If the value is little endian.
   */
  setBigUint64(byteOffset: number, value: bigint, littleEndian?: boolean): void {
    this.dataView?.setBigUint64(byteOffset, value, littleEndian)
  }

  /**
   * Writes the next unsigned long.
   * @param value The value.
   * @param littleEndian If the value is little endian.
   */
  writeBigUint64(value: bigint, littleEndian?: boolean): void {
    this.checkWriteCapacity(8)
    this.setBigUint64(this.mByteOffset, value, littleEndian)
    this.mByteOffset += 8
  }

  /**
   * Gets an signed long.
   * @param byteOffset The byte offset.
   * @param littleEndian If the value is little endian.
   * @returns The value.
   */
  getInt64(byteOffset: number, littleEndian?: boolean): bigint {
    return this.getBigInt64(byteOffset, littleEndian)
  }

  /**
   * Reads the next signed long.
   * @param littleEndian If the value is little endian.
   * @returns The value.
   */
  readInt64(littleEndian?: boolean): bigint {
    const value = this.getInt64(this.mByteOffset, littleEndian)
    this.mByteOffset += 8
    return value
  }

  /**
   * Sets a signed long.
   * @param byteOffset The byte offset.
   * @param value The value.
   * @param littleEndian If the value is little endian.
   */
  setInt64(byteOffset: number, value: number, littleEndian?: boolean): void {
    this.setBigInt64(byteOffset, BigInt(value), littleEndian)
  }

  /**
   * Writes the next signed long.
   * @param value The value.
   * @param littleEndian If the value is little endian.
   */
  writeInt64(value: number, littleEndian?: boolean): void {
    this.checkWriteCapacity(8)
    this.setInt64(this.mByteOffset, value, littleEndian)
    this.mByteOffset += 8
  }

  /**
   * Gets an unsigned long.
   * @param byteOffset The byte offset.
   * @param littleEndian If the value is little endian.
   * @returns The value.
   */
  getUint64(byteOffset: number, littleEndian?: boolean): number {
    return Number(this.getBigUint64(byteOffset, littleEndian))
  }

  /**
   * Reads the next unsigned long.
   * @param littleEndian If the value is little endian.
   * @returns The value.
   */
  readUint64(littleEndian?: boolean): number {
    const value = this.getUint64(this.mByteOffset, littleEndian)
    this.mByteOffset += 8
    return value
  }

  /**
   * Sets an unsigned long.
   * @param byteOffset The byte offset.
   * @param value The value.
   * @param littleEndian If the value is little endian.
   */
  setUint64(byteOffset: number, value: number, littleEndian?: boolean): void {
    this.setBigUint64(byteOffset, BigInt(value), littleEndian)
  }

  /**
   * Writes the next signed long.
   * @param value The value.
   * @param littleEndian If the value is little endian.
   */
  writeUint64(value: number, littleEndian?: boolean): void {
    this.checkWriteCapacity(8)
    this.setUint64(this.mByteOffset, value, littleEndian)
    this.mByteOffset += 8
  }

  /**
   * Gets an array of unsigned bytes.
   * @param byteOffset The byte offset.
   * @param byteLength The byte length.
   * @returns The value.
   */
  getUint8Array(byteOffset: number, byteLength?: number): Uint8Array {
    return this.dataView == null ?
      new Uint8Array(StringUtils.stringToArrayBuffer(""), byteOffset, byteLength) :
      new Uint8Array(this.dataView?.buffer, this.dataView?.byteOffset + byteOffset, byteLength)
  }

  /**
   * Reads the next array of unsigned bytes.
   * @param byteLength The byte length.
   * @returns The value.
   */
  readUint8Array(byteLength?: number): Uint8Array {
    const value = this.getUint8Array(this.mByteOffset, byteLength)
    this.mByteOffset += value.byteLength
    return value
  }

  /**
   * Sets an array of unsigned bytes.
   * @param byteOffset The byte offset.
   * @param value The value.
   */
  setUint8Array(byteOffset: number, value: Uint8Array): void {
    const byteLength = value.byteLength
    this.getUint8Array(byteOffset, byteLength).set(value)
  }

  /**
   * Writes the next array of unsigned bytes.
   * @param value The value.
   */
  writeUint8Array(value: Uint8Array): void {
    this.checkWriteCapacity(value.byteLength)
    this.setUint8Array(this.mByteOffset, value)
    this.mByteOffset += value.byteLength
  }

  /**
   * Gets an array of unsigned shorts.
   * @param byteOffset The byte offset.
   * @param byteLength The byte length.
   * @returns The value.
   */
  getUint16Array(byteOffset: number, byteLength?: number): Uint16Array {
    if (byteLength !== undefined) {
      byteLength = Math.floor(byteLength / 2)
    }
    return this.dataView == null ?
      new Uint16Array(StringUtils.stringToArrayBuffer(""), byteOffset, byteLength) :
      new Uint16Array(this.dataView.buffer, this.dataView.byteOffset + byteOffset, byteLength)
  }

  /**
   * Reads the next array of unsigned shorts.
   * @param byteLength The byte length.
   * @returns The value.
   */
  readUint16Array(byteLength?: number): Uint16Array {
    const value = this.getUint16Array(this.mByteOffset, byteLength)
    this.mByteOffset += value.byteLength
    return value
  }

  /**
   * Sets an array of unsigned bytes.
   * @param byteOffset The byte offset.
   * @param value The value.
   */
  setUint16Array(byteOffset: number, value: Uint16Array): void {
    const byteLength = value.byteLength
    this.getUint16Array(byteOffset, byteLength).set(value)
  }

  /**
   * Writes the next array of unsigned bytes.
   * @param value The value.
   */
  writeUint16Array(value: Uint16Array): void {
    this.checkWriteCapacity(value.byteLength)
    this.setUint16Array(this.mByteOffset, value)
    this.mByteOffset += value.byteLength
  }

  /**
   * Gets a string.
   * @param byteOffset The byte offset.
   * @param byteLength The byte length.
   * @param byteEncoding The byte encoding.
   * @returns The value.
   */
  getString(byteOffset: number, byteLength?: number, byteEncoding?: string): string {
    const decoder = new util.TextDecoder(byteEncoding || "utf-8")
    const encoded = this.getUint8Array(byteOffset, byteLength)
    return decoder.decode(encoded)
  }

  /**
   * Reads the next string.
   * @param byteLength The byte length.
   * @param byteEncoding The byte encoding.
   * @returns The value.
   */
  readString(byteLength?: number, byteEncoding?: string): string {
    const value = this.getString(this.mByteOffset, byteLength, byteEncoding)
    if (byteLength === undefined) {
      this.mByteOffset = this.dataView?.byteLength ?? 0
    } else {
      this.mByteOffset += byteLength
    }
    return value
  }

  /**
   * Sets a string.
   * @param byteOffset The byte offset.
   * @param value The string.
   * @param byteEncoding The byte encoding.
   * @returns The byte length.
   */
  setString(byteOffset: number, value: string, byteEncoding?: string, write?: boolean): number {
    if (byteEncoding && byteEncoding !== "utf-8") {
      throw new TypeError("String encoding '" + byteEncoding + "' is not supported")
    }
    const encoder = new util.TextEncoder()
    const byteLength = Math.min(this.dataView!.byteLength - byteOffset, value.length * 4)
    if (write) {
      this.checkWriteCapacity(byteLength)
    }
    const destination = this.getUint8Array(byteOffset, byteLength)
    const written = encoder.encodeInto(value, destination).written
    return written || 0
  }

  /**
   * Writes the next a string.
   * @param value The string.
   * @param byteEncoding The byte encoding.
   */
  writeString(value: string, byteEncoding?: string): void {
    const byteLength = this.setString(this.mByteOffset, value, byteEncoding, true)
    this.mByteOffset += byteLength
  }

  /**
   * Formats to a string.
   * @param format The string format.
   * @returns The string.
   */
  toString(format?: string): string {
    return [...this.getUint8Array(0)].map((byte: number) => {
      switch (format) {
        case "hex":
          return ("00" + byte.toString(16)).slice(-2)
        default:
          return byte.toString(10)
      }
    }).join(" ")
  }
}