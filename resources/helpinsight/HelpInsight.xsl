<?xml version="1.0" encoding="UTF-8"?>
<!-- XmlDocPlugin native Help Insight. XSLT 1.0; no script, external documents or resources. -->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
 <xsl:output method="html" encoding="UTF-8" omit-xml-declaration="yes"/>
 <xsl:template match="/">
  <xsl:if test="normalize-space(member/@DisplayName) or normalize-space(member/@name) or normalize-space(member/identifier) or normalize-space(member/source/@declaredInShort) or normalize-space(member/source/@declaredIn) or member/*[self::summary or self::typeparam or self::param or self::returns or self::value or self::exception or self::remarks or self::example or self::seealso or self::comments or self::permission][normalize-space(.) or .//@cref or .//@href or @cref or @href or @name]">
  <html><head><title><xsl:value-of select="member/@DisplayName"/></title><meta http-equiv="Content-Type" content="text/html; charset=utf-8"/><link rel="stylesheet" type="text/css" href="HelpInsight.css"/><style type="text/css">@@CSS@@</style></head>
   <body><div class="xmldoc-hint">
    <xsl:if test="normalize-space(member/@DisplayName) or normalize-space(member/@name) or normalize-space(member/identifier) or normalize-space(member/source/@declaredInShort) or normalize-space(member/source/@declaredIn)"><div class="hint-caption"><xsl:choose><xsl:when test="member/source"><a href="helpinsight:/filelink:{member/source/@declaredIn}?{member/source/@declaredOn},{member/source/@declaredAt}"><xsl:value-of select="member/@DisplayName"/></a></xsl:when><xsl:otherwise><xsl:value-of select="member/@DisplayName"/></xsl:otherwise></xsl:choose></div></xsl:if>
    <xsl:apply-templates select="member/summary"/>
    <xsl:if test="member/typeparam"><h4>@@Type Parameters@@</h4><dl><xsl:apply-templates select="member/typeparam"/></dl></xsl:if>
    <xsl:if test="member/param"><h4>@@Parameters@@</h4><dl><xsl:apply-templates select="member/param"/></dl></xsl:if>
    <xsl:if test="member/returns"><h4>@@Returns@@</h4><xsl:apply-templates select="member/returns"/></xsl:if>
    <xsl:if test="member/value"><h4>@@Value@@</h4><xsl:apply-templates select="member/value"/></xsl:if>
    <xsl:if test="member/exception"><h4>@@Exceptions@@</h4><dl><xsl:apply-templates select="member/exception"/></dl></xsl:if>
    <xsl:if test="member/remarks"><h4>@@Remarks@@</h4><xsl:apply-templates select="member/remarks"/></xsl:if>
    <xsl:if test="member/example"><h4>@@Examples@@</h4><xsl:apply-templates select="member/example"/></xsl:if>
    <xsl:if test="member/seealso"><h4>@@See Also@@</h4><ul><xsl:for-each select="member/seealso"><li><xsl:call-template name="reference"/></li></xsl:for-each></ul></xsl:if>
    <xsl:apply-templates select="member/comments|member/permission"/>
   </div></body>
  </html>
  </xsl:if>
 </xsl:template>
 <xsl:template match="summary|remarks|returns|value|example|comments"><div class="hint-section"><xsl:apply-templates/></div></xsl:template>
 <xsl:template match="param|typeparam"><dt><code><xsl:value-of select="@name"/></code><xsl:if test="@type"><span class="parameter-type"><xsl:text>: </xsl:text><xsl:value-of select="@type"/></span></xsl:if></dt><dd><xsl:apply-templates/></dd></xsl:template>
 <xsl:template match="exception|permission"><dt><xsl:call-template name="reference"/></dt><dd><xsl:apply-templates/></dd></xsl:template>
 <xsl:template match="para|p|P"><p><xsl:apply-templates/></p></xsl:template>
 <xsl:template match="b|B|strong"><b><xsl:apply-templates/></b></xsl:template>
 <xsl:template match="i|I|em"><i><xsl:apply-templates/></i></xsl:template>
 <xsl:template match="br|BR"><br/></xsl:template>
 <xsl:template match="c|C|paramref|typeparamref"><code><xsl:choose><xsl:when test="@name"><xsl:value-of select="@name"/></xsl:when><xsl:otherwise><xsl:apply-templates/></xsl:otherwise></xsl:choose></code></xsl:template>
 <xsl:template match="code|CODE"><pre><code><xsl:apply-templates/></code></pre></xsl:template>
 <xsl:template match="list[@type='bullet']"><ul><xsl:apply-templates select="item"/></ul></xsl:template>
 <xsl:template match="list[@type='number']"><ol><xsl:apply-templates select="item"/></ol></xsl:template>
 <xsl:template match="list[@type='table']"><table class="hint-table"><xsl:if test="listheader"><thead><tr><xsl:for-each select="listheader/term|listheader/description"><th><xsl:apply-templates/></th></xsl:for-each></tr></thead></xsl:if><tbody><xsl:for-each select="item"><tr><td><xsl:apply-templates select="term/node()"/></td><td><xsl:apply-templates select="description/node()"/></td></tr></xsl:for-each></tbody></table></xsl:template>
 <xsl:template match="list"><dl><xsl:for-each select="item"><dt><xsl:apply-templates select="term/node()"/></dt><dd><xsl:apply-templates select="description/node()"/></dd></xsl:for-each></dl></xsl:template>
 <xsl:template match="item"><li><xsl:if test="term"><b><xsl:apply-templates select="term/node()"/></b><xsl:text> </xsl:text></xsl:if><xsl:choose><xsl:when test="description"><xsl:apply-templates select="description/node()"/></xsl:when><xsl:otherwise><xsl:apply-templates select="node()[not(self::term)]"/></xsl:otherwise></xsl:choose></li></xsl:template>
 <xsl:template match="note"><div class="hint-note"><div class="hint-note-title"><xsl:choose><xsl:when test="@type='caller'">@@Notes to callers@@</xsl:when><xsl:when test="@type='warning' or @type='caution'">@@Warning@@</xsl:when><xsl:when test="@type='tip'">@@Tip@@</xsl:when><xsl:otherwise>@@Note@@</xsl:otherwise></xsl:choose></div><div class="hint-note-content"><xsl:apply-templates/></div></div></xsl:template>
 <xsl:template name="reference"><xsl:choose><xsl:when test="@href and (starts-with(@href,'https://') or starts-with(@href,'http://') or starts-with(@href,'helpinsight:/'))"><a href="{@href}"><xsl:call-template name="reference-label"/></a></xsl:when><xsl:when test="@cref"><a href="helpinsight:/typelink:{translate(@cref,'&lt;&gt;','{}')}"><xsl:call-template name="reference-label"/></a></xsl:when><xsl:when test="@langword"><code><xsl:value-of select="@langword"/></code></xsl:when><xsl:otherwise><xsl:apply-templates/></xsl:otherwise></xsl:choose></xsl:template>
 <xsl:template name="reference-label"><xsl:choose><xsl:when test="normalize-space(.) and not(self::exception) and not(self::permission)"><xsl:apply-templates/></xsl:when><xsl:when test="@DisplayName"><xsl:value-of select="@DisplayName"/></xsl:when><xsl:when test="@cref"><xsl:value-of select="@cref"/></xsl:when><xsl:otherwise><xsl:value-of select="@href"/></xsl:otherwise></xsl:choose></xsl:template>
 <xsl:template match="see|seealso|a"><xsl:call-template name="reference"/></xsl:template>
 <xsl:template match="ul|ol|li|table|thead|tbody|tr|th|td|u|sup|sub|blockquote"><xsl:element name="{local-name()}"><xsl:apply-templates/></xsl:element></xsl:template>
 <xsl:template match="script|style|iframe|object|embed|img"/>
 <xsl:template match="text()"><xsl:value-of select="."/></xsl:template>
 <xsl:template match="*"><xsl:apply-templates/></xsl:template>
</xsl:stylesheet>
