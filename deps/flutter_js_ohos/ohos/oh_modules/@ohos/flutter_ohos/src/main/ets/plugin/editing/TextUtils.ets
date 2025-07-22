/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on FlutterTextUtils.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/
import FlutterNapi from '../../embedding/engine/FlutterNapi';
import Log from '../../util/Log';

const LINE_FEED: number = 0x0A;
const CARRIAGE_RETURN: number = 0x0D;
const COMBINING_ENCLOSING_KEYCAP: number = 0x20E3;
const CANCEL_TAG: number = 0xE007F;
const ZERO_WIDTH_JOINER: number = 0x200D;

const TAG = "TextUtils";

export class FlutterTextUtils {
    
  static isEmoji(code: number): boolean {
    return FlutterNapi.unicodeIsEmoji(code);
  }

  static isEmojiModifier(code: number): boolean {
    return FlutterNapi.unicodeIsEmojiModifier(code);
  }
  
  static isEmojiModifierBase(code: number): boolean {
    return FlutterNapi.unicodeIsEmojiModifierBase(code);
  }

  static isVariationSelector(code: number): boolean {
    return FlutterNapi.unicodeIsVariationSelector(code);
  }

  static isRegionalIndicatorSymbol(code: number): boolean {
    return FlutterNapi.unicodeIsRegionalIndicatorSymbol(code);
  }

  static isTagSpecChar(code: number): boolean {
    return 0xE0020 <= code && code <= 0xE007E;
  }

  static isKeycapBase(code: number): boolean {
    return ('0'.charCodeAt(0) <= code && code <= '9'.charCodeAt(0)) || code == '#'.charCodeAt(0) || code == '*'.charCodeAt(0);
  }

  static codePointBefore(text: string, offset: number): number {
    if (offset <= 0 || offset > text.length) {
        throw new RangeError('Offset out of range');
    }

    // Get the character before the offset
    const char = text[offset - 1];

    // Check if it is a low surrogate (part of a surrogate pair)
    if (offset > 1 && char >= '\uDC00' && char <= '\uDFFF') {
        const prevChar = text[offset - 2];
        // Check if the previous character is a high surrogate
        if (prevChar >= '\uD800' && prevChar <= '\uDBFF') {
          // If it is, combine the surrogate pair into a full Unicode code point
          return (prevChar.charCodeAt(0) - 0xD800) * 0x400 + (char.charCodeAt(0) - 0xDC00) + 0x10000;
        }
    }

    // Return the code point of the single character (if it's not a surrogate pair)
    return char.charCodeAt(0);
  }

  static codePointAt(text: string, offset: number): number {
    if (offset >= text.length) {
        throw new RangeError('Offset out of range');
    }
    let char = text[offset];

    // Check if it is a high surrogate (part of a surrogate pair)
    if (char >= '\uD800' && char <= '\uDBFF' && offset + 1 < text.length) {
        const nextChar = text[offset + 1];
        // Check if the previous character is a low surrogate
        if (nextChar >= '\uDC00' && nextChar <= '\uDFFF') {
          // If it is, combine the surrogate pair into a full Unicode code point
          return (char.charCodeAt(0) - 0xD800) * 0x400 + (nextChar.charCodeAt(0) - 0xDC00) + 0x10000;
        }
    }
    return char.charCodeAt(0);
  }

  static charCount(codePoint: number): number {
    // If the code point is in the BMP range (0x0000 - 0xFFFF), it needs 1 UTF-16 code unit
    if (codePoint <= 0xFFFF) {
      return 1;
    }
    // If the code point is in the supplementary range (0x10000 - 0x10FFFF), it needs 2 UTF-16 code units
    return 2;
  }

  static getOffsetBefore(text: string, offset: number): number {
    if (offset <= 1) {
      return 0;
    }

    let codePoint: number = FlutterTextUtils.codePointBefore(text, offset);
    let deleteCharCount: number = FlutterTextUtils.charCount(codePoint);
    let lastOffset: number = offset - deleteCharCount;

    if (lastOffset == 0) {
      return 0;
    }

    // Line Feed
    if (codePoint == LINE_FEED) {
      codePoint = FlutterTextUtils.codePointBefore(text, lastOffset);
      if (codePoint == CARRIAGE_RETURN) {
        ++deleteCharCount;
      }
      return offset - deleteCharCount;
    }

    // Flags
    if (FlutterTextUtils.isRegionalIndicatorSymbol(codePoint)) {
      codePoint = FlutterTextUtils.codePointBefore(text, lastOffset);
      lastOffset -= FlutterTextUtils.charCount(codePoint);
      let regionalIndicatorSymbolCount: number = 1;
      while (lastOffset > 0 && FlutterTextUtils.isRegionalIndicatorSymbol(codePoint)) {
        codePoint = FlutterTextUtils.codePointBefore(text, lastOffset);
        lastOffset -= FlutterTextUtils.charCount(codePoint);
        regionalIndicatorSymbolCount++;
      }
      if (FlutterTextUtils.isRegionalIndicatorSymbol(codePoint)) {
        regionalIndicatorSymbolCount++;
      }
      if (regionalIndicatorSymbolCount % 2 == 0) {
        deleteCharCount += 2;
      }
      return offset - deleteCharCount;
    }

    // Keycaps
    if (codePoint == COMBINING_ENCLOSING_KEYCAP) {
      codePoint = FlutterTextUtils.codePointBefore(text, lastOffset);
      lastOffset -= FlutterTextUtils.charCount(codePoint);
      if (lastOffset > 0 && FlutterTextUtils.isVariationSelector(codePoint)) {
        let tmpCodePoint: number = FlutterTextUtils.codePointBefore(text, lastOffset);
        if (FlutterTextUtils.isKeycapBase(tmpCodePoint)) {
          deleteCharCount += FlutterTextUtils.charCount(codePoint) + FlutterTextUtils.charCount(tmpCodePoint);
        }
      } else if (FlutterTextUtils.isKeycapBase(codePoint)) {
        deleteCharCount += FlutterTextUtils.charCount(codePoint);
      }
      return offset - deleteCharCount;
    }

    /**
     * Following if statements for Emoji tag sequence and Variation selector are skipping these
     * modifiers for going through the last statement that is for handling emojis. They return the
     * offset if they don't find proper base characters
     */
    // Emoji Tag Sequence
    if (codePoint == CANCEL_TAG) { // tag_end
      codePoint = FlutterTextUtils.codePointBefore(text, lastOffset);
      lastOffset -= FlutterTextUtils.charCount(codePoint);
      while (lastOffset > 0 && FlutterTextUtils.isTagSpecChar(codePoint)) { // tag_spec
        deleteCharCount += FlutterTextUtils.charCount(codePoint);
        codePoint = FlutterTextUtils.codePointBefore(text, lastOffset);
        lastOffset -= FlutterTextUtils.charCount(codePoint);
      }
      if (!FlutterTextUtils.isEmoji(codePoint)) { // tag_base not found. Just delete the end.
        return offset - 2;
      }
      deleteCharCount += FlutterTextUtils.charCount(codePoint);
    }

    if (FlutterTextUtils.isVariationSelector(codePoint)) {
      codePoint = FlutterTextUtils.codePointBefore(text, lastOffset);
      if (!FlutterTextUtils.isEmoji(codePoint)) {
        return offset - deleteCharCount;
      }
      deleteCharCount += FlutterTextUtils.charCount(codePoint);

      lastOffset -= FlutterTextUtils.charCount(codePoint);
    }

    if (FlutterTextUtils.isEmoji(codePoint)) {
      let isZwj: boolean = false;
      let lastSeenVariantSelectorCharCount: number = 0;
      do {
        if (isZwj) {
          deleteCharCount += FlutterTextUtils.charCount(codePoint) + lastSeenVariantSelectorCharCount + 1;
          isZwj = false;
        }
        lastSeenVariantSelectorCharCount = 0;
        if (FlutterTextUtils.isEmojiModifier(codePoint)) {
          codePoint = FlutterTextUtils.codePointBefore(text, lastOffset);
          lastOffset -= FlutterTextUtils.charCount(codePoint);
          if (lastOffset > 0 && FlutterTextUtils.isVariationSelector(codePoint)) {
            codePoint = FlutterTextUtils.codePointBefore(text, lastOffset);
            if (!FlutterTextUtils.isEmoji(codePoint)) {
              return offset - deleteCharCount;
            }
            lastSeenVariantSelectorCharCount = FlutterTextUtils.charCount(codePoint);
            lastOffset -= FlutterTextUtils.charCount(codePoint);
          }
          if (FlutterTextUtils.isEmojiModifierBase(codePoint)) {
            deleteCharCount += lastSeenVariantSelectorCharCount + FlutterTextUtils.charCount(codePoint);
          }
          break;
        }

        if (lastOffset > 0) {
          codePoint = FlutterTextUtils.codePointBefore(text, lastOffset);
          lastOffset -= FlutterTextUtils.charCount(codePoint);
          if (codePoint == ZERO_WIDTH_JOINER) {
            isZwj = true;
            codePoint = FlutterTextUtils.codePointBefore(text, lastOffset);
            lastOffset -= FlutterTextUtils.charCount(codePoint);
            if (lastOffset > 0 && FlutterTextUtils.isVariationSelector(codePoint)) {
              codePoint = FlutterTextUtils.codePointBefore(text, lastOffset);
              lastSeenVariantSelectorCharCount = FlutterTextUtils.charCount(codePoint);
              lastOffset -= FlutterTextUtils.charCount(codePoint);
            }
          }
        }

        if (lastOffset == 0) {
          break;
        }
      } while (isZwj && FlutterTextUtils.isEmoji(codePoint));

      if (isZwj && lastOffset == 0) {
        deleteCharCount += FlutterTextUtils.charCount(codePoint) + lastSeenVariantSelectorCharCount + 1;
        isZwj = false;
      }
    }

    return offset - deleteCharCount;
  }

  static getOffsetAfter(text: string, offset: number): number {
    const len = text.length;
    if (offset >= len - 1) {
      return len;
    }

    let codePoint: number = FlutterTextUtils.codePointAt(text, offset);
    let nextCharCount: number = FlutterTextUtils.charCount(codePoint);
    let nextOffset: number = offset + nextCharCount;

    if (nextOffset == 0) {
      return 0;
    }
    // Line Feed
    if (codePoint == LINE_FEED) {
      codePoint = FlutterTextUtils.codePointAt(text, nextOffset);
      if (codePoint == CARRIAGE_RETURN) {
        ++nextCharCount;
      }
      return offset + nextCharCount;
    }

    // Flags
    if (FlutterTextUtils.isRegionalIndicatorSymbol(codePoint)) {
      if (nextOffset >= len - 1
          || !FlutterTextUtils.isRegionalIndicatorSymbol(FlutterTextUtils.codePointAt(text, nextOffset))) {
        return offset + nextCharCount;
      }
      // In this case there are at least two regional indicator symbols ahead of
      // offset. If those two regional indicator symbols are a pair that
      // represent a region together, the next offset should be after both of
      // them.
      let regionalIndicatorSymbolCount: number = 0;
      let regionOffset: number = offset;
      while (regionOffset > 0
          && FlutterTextUtils.isRegionalIndicatorSymbol(FlutterTextUtils.codePointBefore(text, regionOffset))) {
        regionOffset -= FlutterTextUtils.charCount(FlutterTextUtils.codePointBefore(text, regionOffset));
        regionalIndicatorSymbolCount++;
      }
      if (regionalIndicatorSymbolCount % 2 == 0) {
        nextCharCount += 2;
      }
      return offset + nextCharCount;
    }

    // Keycaps
    if (FlutterTextUtils.isKeycapBase(codePoint)) {
      nextCharCount += FlutterTextUtils.charCount(codePoint);
    }
    if (codePoint == COMBINING_ENCLOSING_KEYCAP) {
      codePoint = FlutterTextUtils.codePointBefore(text, nextOffset);
      nextOffset += FlutterTextUtils.charCount(codePoint);
      if (nextOffset < len && FlutterTextUtils.isVariationSelector(codePoint)) {
        let tmpCodePoint: number = FlutterTextUtils.codePointAt(text, nextOffset);
        if (FlutterTextUtils.isKeycapBase(tmpCodePoint)) {
          nextCharCount += FlutterTextUtils.charCount(codePoint) + FlutterTextUtils.charCount(tmpCodePoint);
        }
      } else if (FlutterTextUtils.isKeycapBase(codePoint)) {
        nextCharCount += FlutterTextUtils.charCount(codePoint);
      }
      return offset + nextCharCount;
    }

    if (FlutterTextUtils.isEmoji(codePoint)) {
      let isZwj: boolean = false;
      let lastSeenVariantSelectorCharCount: number = 0;
      do {
        if (isZwj) {
          nextCharCount += FlutterTextUtils.charCount(codePoint) + lastSeenVariantSelectorCharCount + 1;
          isZwj = false;
        }
        lastSeenVariantSelectorCharCount = 0;
        if (FlutterTextUtils.isEmojiModifier(codePoint)) {
          break;
        }

        if (nextOffset < len) {
          codePoint = FlutterTextUtils.codePointAt(text, nextOffset);
          nextOffset += FlutterTextUtils.charCount(codePoint);
          if (codePoint == COMBINING_ENCLOSING_KEYCAP) {
            codePoint = FlutterTextUtils.codePointBefore(text, nextOffset);
            nextOffset += FlutterTextUtils.charCount(codePoint);
            if (nextOffset < len && FlutterTextUtils.isVariationSelector(codePoint)) {
              let tmpCodePoint: number = FlutterTextUtils.codePointAt(text, nextOffset);
              if (FlutterTextUtils.isKeycapBase(tmpCodePoint)) {
                nextCharCount += FlutterTextUtils.charCount(codePoint) + FlutterTextUtils.charCount(tmpCodePoint);
              }
            } else if (FlutterTextUtils.isKeycapBase(codePoint)) {
              nextCharCount += FlutterTextUtils.charCount(codePoint);
            }
            return offset + nextCharCount;
          }
          if (FlutterTextUtils.isEmojiModifier(codePoint)) {
            nextCharCount += lastSeenVariantSelectorCharCount + FlutterTextUtils.charCount(codePoint);
            break;
          }
          if (FlutterTextUtils.isVariationSelector(codePoint)) {
            nextCharCount += lastSeenVariantSelectorCharCount + FlutterTextUtils.charCount(codePoint);
            break;
          }
          if (codePoint == ZERO_WIDTH_JOINER) {
            isZwj = true;
            codePoint = FlutterTextUtils.codePointAt(text, nextOffset);
            nextOffset += FlutterTextUtils.charCount(codePoint);
            if (nextOffset < len && FlutterTextUtils.isVariationSelector(codePoint)) {
              codePoint = FlutterTextUtils.codePointAt(text, nextOffset);
              lastSeenVariantSelectorCharCount = FlutterTextUtils.charCount(codePoint);
              nextOffset += FlutterTextUtils.charCount(codePoint);
            }
          }
        }

        if (nextOffset >= len) {
          break;
        }
      } while (isZwj && FlutterTextUtils.isEmoji(codePoint));

      if (isZwj && nextOffset >= len) {
        nextCharCount += FlutterTextUtils.charCount(codePoint) + lastSeenVariantSelectorCharCount + 1;
        isZwj = false;
      }
    }

    return offset + nextCharCount;
  }
}
