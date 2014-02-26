using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.Xml;

using JetBrains.Annotations;
using JetBrains.Util;

namespace JetBrains.Platform.PowerShell.Infra.TeamCity
{
  /// <summary>
  ///   While running within a TeamCity build, we have three sets of properties available:
  ///   (1) Environment. These are available thru the process environment block.
  ///   (2) System. There's a pointer to the properties file in one of the environment variables.
  ///   (3) Configuration.There's a pointer to the properties file in one of the system properties (see the chain?).
  /// </summary>
  public class TeamCityProperties
  {
    #region Data

    private IDictionary<string, string> myConfigurationProperties;

    private IDictionary<string, string> mySystemProperties;

    #endregion

    #region Attributes

    public readonly bool IsRunningInTeamCity = !TryGetSystemPropertiesFilePath().IsNullOrEmpty();

    #endregion

    #region Operations

    [NotNull]
    public string GetConfigurationProperty([NotNull] string name)
    {
      if(name == null)
        throw new ArgumentNullException("name");
      AssertIsRunningInTeamCity();
      TryLoadConfigurationPropertiesFile();
      return myConfigurationProperties.GetValue(name, string.Format("The configuration property {0} is not defined.", name.QuoteIfNeeded()));
    }

    [NotNull]
    public string GetSystemProperty([NotNull] string name)
    {
      if(name == null)
        throw new ArgumentNullException("name");
      name = Regex.Replace(name, @"^system\.", "", RegexOptions.IgnoreCase); // Props are listed without the "system." prefix in the file
      AssertIsRunningInTeamCity();
      TryLoadSystemPropertiesFile();
      return mySystemProperties.GetValue(name, string.Format("The system property {0} is not defined.", name.QuoteIfNeeded()));
    }

    [CanBeNull]
    public string TryGetConfigurationProperty([NotNull] string name)
    {
      if(name == null)
        throw new ArgumentNullException("name");
      TryLoadConfigurationPropertiesFile();
      return myConfigurationProperties != null ? myConfigurationProperties.TryGetValue(name) : null;
    }

    [CanBeNull]
    public string TryGetSystemProperty([NotNull] string name)
    {
      if(name == null)
        throw new ArgumentNullException("name");
      name = Regex.Replace(name, @"^system\.", "", RegexOptions.IgnoreCase); // Props are listed without the "system." prefix in the file
      TryLoadSystemPropertiesFile();
      return mySystemProperties != null ? mySystemProperties.TryGetValue(name) : null;
    }

    #endregion

    #region Implementation

    [NotNull]
    private static IDictionary<string, string> ReadJavaPropertiesXml([NotNull] FileSystemPath pathFile)
    {
      if(pathFile == null)
        throw new ArgumentNullException("pathFile");

      var xmlDoc = new XmlDocument();
      pathFile.ReadStream(xmlDoc.Load);

      return xmlDoc.SelectElements("//entry").ToDictionary(xmlEntry => xmlEntry.GetAttribute("key"), xmlEntry => xmlEntry.InnerText);
    }

    [NotNull]
    private static FileSystemPath TryGetSystemPropertiesFilePath()
    {
      FileSystemPath path = FileSystemPath.TryParse(Environment.GetEnvironmentVariable("TEAMCITY_BUILD_PROPERTIES_FILE"));
      if(path.IsEmpty)
        return FileSystemPath.Empty;

      // Switch to an XML representation of the properties file
      path = new FileSystemPath(path.FullPath + ".xml");

      return path.ExistsFile ? path : FileSystemPath.Empty;
    }

    private void AssertIsRunningInTeamCity()
    {
      if(!IsRunningInTeamCity)
        throw new InvalidOperationException("This code is not currently running within a TeamCity build agent process.");
    }

    private void TryLoadConfigurationPropertiesFile()
    {
      if(!IsRunningInTeamCity)
        return;
      if(myConfigurationProperties != null)
        return;

      var pathFile = new FileSystemPath(GetSystemProperty("teamcity.configuration.properties.file") + ".xml");
      if(!pathFile.ExistsFile)
        return;

      myConfigurationProperties = ReadJavaPropertiesXml(pathFile);
    }

    private void TryLoadSystemPropertiesFile()
    {
      if(!IsRunningInTeamCity)
        return;
      if(mySystemProperties != null)
        return;

      FileSystemPath pathFile = TryGetSystemPropertiesFilePath();
      if(!pathFile.ExistsFile)
        return;

      mySystemProperties = ReadJavaPropertiesXml(pathFile);
    }

    #endregion
  }
}