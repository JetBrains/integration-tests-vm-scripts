using System;

using JetBrains.Annotations;
using JetBrains.Util;

using Microsoft.Build.Utilities;

namespace JetBrains.Platform.PowerShell.Infra.TeamCity
{
  public static class TeamCityNetfxTools
  {
    #region Operations

    /// <summary>
    ///   Gets the parameter value for MSBuild's "/logger:" parameter which connects it to the TeamCity logger, if currently running in a TeamCity build agent.
    /// </summary>
    [CanBeNull]
    public static string TryGetTeamCityMsbuildLoggerParam(TargetDotNetFrameworkVersion version, TeamCityProperties tc = null)
    {
      tc = tc ?? new TeamCityProperties();

      if(!tc.IsRunningInTeamCity)
        return null;

      // Differs by MSBuild version
      if(version < TargetDotNetFrameworkVersion.Version20)
        return null;
      string prop = version >= TargetDotNetFrameworkVersion.Version40 ? "teamcity.dotnet.msbuild.extensions4.0" : "teamcity.dotnet.msbuild.extensions2.0";

      // Read path from TC config
      var pathDll = new FileSystemPath(tc.GetConfigurationProperty(prop));
      if(!pathDll.ExistsFile)
        throw new InvalidOperationException("There's the TeamCity MSBuild logger path, but it does not exist on disk.");

      // Make the path
      string sClassName = "JetBrains.BuildServer.MSBuildLoggers.MSBuildLogger";

      return sClassName + "," + pathDll.FullPath + ";";
    }

    #endregion
  }
}